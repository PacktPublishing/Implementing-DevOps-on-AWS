#!/usr/bin/env python
# Cob: yet another yum S3 plugin
#
# Copyright 2014-2015, Henry Huang <henry.s.huang@gmail.com>.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

__version__ = "0.3.1"

import base64
import hmac
import json
import re
import socket
import datetime
import time
import urllib2
import urlparse
from hashlib import sha256
from email.message import Message
from urlparse import urlsplit

import yum.plugins
from yum.yumRepo import YumRepository

__all__ = ['requires_api_version',
           'plugin_type',
           'init_hook']

requires_api_version = '2.5'
plugin_type = yum.plugins.TYPE_CORE

timeout = 60
retries = 5
metadata_server = "http://169.254.169.254"

EMPTY_SHA256_HASH = (
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')


class HTTPHeaders(Message):

    # The __iter__ method is not available in python2.x, so we have
    # to port the py3 version.
    def __iter__(self):
        for field, value in self._headers:
            yield field


class NoCredentialsError(Exception):
    """
    No credentials could be found
    """
    pass


class NoRegionError(Exception):
    """
    No region could be found
    """
    pass


class IncorrectCredentialsError(Exception):

    """
    Incorrect Credentials could be found"
    """
    pass


class Credentials(object):
    def __init__(self, access_key, secret_key, token):
        self.access_key = access_key
        self.secret_key = secret_key
        self.token = token


class HTTPRequest(object):
    def __init__(self, method, url, headers=None):
        self.method = method
        self.url = url

        if headers is None:
            self.headers = {}
        else:
            self.headers = headers


class BaseSigner(object):
    def add_auth(self, request):
        raise NotImplementedError("add_auth")


class S3SigV4Auth(BaseSigner):
    """
    Sign a S3 request with Signature V4.
    """
    def __init__(self, credentials, service_name, region_name, logger):
        self.credentials = credentials
        # We initialize these value here so the unit tests can have
        # valid values.  But these will get overriden in ``add_auth``
        # later for real requests.
        now = datetime.datetime.utcnow()
        self.timestamp = now.strftime('%Y%m%dT%H%M%SZ')
        self._region_name = region_name
        self._service_name = service_name
        self._logger = logger

    def _sign(self, key, msg, hex=False):
        if hex:
            sig = hmac.new(key, msg.encode('utf-8'), sha256).hexdigest()
        else:
            sig = hmac.new(key, msg.encode('utf-8'), sha256).digest()
        return sig

    def headers_to_sign(self, request):
        """
        Select the headers from the request that need to be included
        in the StringToSign.
        """
        header_map = HTTPHeaders()
        split = urlsplit(request.url)
        for name, value in request.headers.items():
            lname = name.lower()
            header_map[lname] = value
        if 'host' not in header_map:
            header_map['host'] = split.netloc
        return header_map

    def canonical_headers(self, headers_to_sign):
        """
        Return the headers that need to be included in the StringToSign
        in their canonical form by converting all header keys to lower
        case, sorting them in alphabetical order and then joining
        them into a string, separated by newlines.
        """
        headers = []
        sorted_header_names = sorted(set(headers_to_sign))
        for key in sorted_header_names:
            value = ','.join(v.strip() for v in
                             sorted(headers_to_sign.get_all(key)))
            headers.append('%s:%s' % (key, value))
        return '\n'.join(headers)

    def signed_headers(self, headers_to_sign):
        l = ['%s' % n.lower().strip() for n in set(headers_to_sign)]
        l = sorted(l)
        return ';'.join(l)

    def canonical_request(self, request):
        cr = [request.method.upper()]
        path = self._normalize_url_path(urlsplit(request.url).path)
        cr.append(path)
        headers_to_sign = self.headers_to_sign(request)
        cr.append(self.canonical_headers(headers_to_sign) + '\n')
        cr.append(self.signed_headers(headers_to_sign))
        if 'X-Amz-Content-SHA256' in request.headers:
            body_checksum = request.headers['X-Amz-Content-SHA256']
        else:
            body_checksum = EMPTY_SHA256_HASH
        cr.append(body_checksum)
        return '\n'.join(cr)

    def _normalize_url_path(self, path):
        # For S3, we do not normalize the path.
        return path

    def scope(self, args):
        scope = [self.credentials.access_key]
        scope.append(self.timestamp[0:8])
        scope.append(self._region_name)
        scope.append(self._service_name)
        scope.append('aws4_request')
        return '/'.join(scope)

    def credential_scope(self, args):
        scope = []
        scope.append(self.timestamp[0:8])
        scope.append(self._region_name)
        scope.append(self._service_name)
        scope.append('aws4_request')
        return '/'.join(scope)

    def string_to_sign(self, request, canonical_request):
        """
        Return the canonical StringToSign as well as a dict
        containing the original version of all headers that
        were included in the StringToSign.
        """
        sts = ['AWS4-HMAC-SHA256']
        sts.append(self.timestamp)
        sts.append(self.credential_scope(request))
        sts.append(sha256(canonical_request.encode('utf-8')).hexdigest())
        return '\n'.join(sts)

    def signature(self, string_to_sign):
        key = self.credentials.secret_key
        k_date = self._sign(('AWS4' + key).encode('utf-8'),
                            self.timestamp[0:8])
        k_region = self._sign(k_date, self._region_name)
        k_service = self._sign(k_region, self._service_name)
        k_signing = self._sign(k_service, 'aws4_request')
        return self._sign(k_signing, string_to_sign, hex=True)

    def add_auth(self, request):
        if self.credentials is None:
            raise NoCredentialsError
        # Create a new timestamp for each signing event
        now = datetime.datetime.utcnow()
        self.timestamp = now.strftime('%Y%m%dT%H%M%SZ')
        # This could be a retry.  Make sure the previous
        # authorization header is removed first.
        self._modify_request_before_signing(request)
        canonical_request = self.canonical_request(request)
        self._logger.info(3, "Calculating signature using v4 auth.")
        self._logger.info(3, "CanonicalRequest:\n%s\n" % canonical_request)
        string_to_sign = self.string_to_sign(request, canonical_request)
        self._logger.info(3, "StringToSign:\n%s\n" % string_to_sign)
        signature = self.signature(string_to_sign)
        self._logger.info(3, "Signature: %s" % signature)

        self._inject_signature_to_request(request, signature)

    def _inject_signature_to_request(self, request, signature):
        l = ['AWS4-HMAC-SHA256 Credential=%s' % self.scope(request)]
        headers_to_sign = self.headers_to_sign(request)
        l.append('SignedHeaders=%s' % self.signed_headers(headers_to_sign))
        l.append('Signature=%s' % signature)
        request.headers['Authorization'] = ', '.join(l)
        return request

    def _modify_request_before_signing(self, request):
        if 'Authorization' in request.headers:
            del request.headers['Authorization']
        if 'Date' not in request.headers:
            request.headers['X-Amz-Date'] = self.timestamp
        if self.credentials.token:
            request.headers['X-Amz-Security-Token'] = self.credentials.token
        request.headers['X-Amz-Content-SHA256'] = EMPTY_SHA256_HASH


def _check_s3_urls(urls):
    pattern = "s3.*\.amazonaws\.com"
    if isinstance(urls, basestring):
        if re.compile(pattern).findall(urls) != []:
            return True
    elif isinstance(urls, list):
        for url in urls:
            if re.compile(pattern).findall(url) != []:
                break
        else:
            # Only for the list with all non-S3 URLs
            return False
    return True


def get_region_from_s3url(url):
    pattern = "s3-(.*)\.amazonaws\.com"
    groups = re.compile(pattern).findall(url)
    if groups != [] and len(groups) == 1:
        return groups[0]
    else:
        # No region info in S3 URL
        return "us-east-1"


def retry_url(url, retry_on_404=False, num_retries=retries, timeout=timeout):
    """
    Retry a url.  This is specifically used for accessing the metadata
    service on an instance.  Since this address should never be proxied
    (for security reasons), we create a ProxyHandler with a NULL
    dictionary to override any proxy settings in the environment.
    """

    original = socket.getdefaulttimeout()
    socket.setdefaulttimeout(timeout)

    for i in range(0, num_retries):
        try:
            proxy_handler = urllib2.ProxyHandler({})
            opener = urllib2.build_opener(proxy_handler)
            req = urllib2.Request(url)
            r = opener.open(req)
            result = r.read()
            return result
        except urllib2.HTTPError as e:
            # in 2.6 you use getcode(), in 2.5 and earlier you use code
            if hasattr(e, 'getcode'):
                code = e.getcode()
            else:
                code = e.code
            if code == 404 and not retry_on_404:
                return None
        except Exception as e:
            pass
        print '[ERROR] Caught exception reading instance data'
        # If not on the last iteration of the loop then sleep.
        if i + 1 != num_retries:
            time.sleep(2 ** i)
    print '[ERROR] Unable to read instance data, giving up'
    return None


def get_region(url=metadata_server, version="latest",
               params="meta-data/placement/availability-zone/"):
    """
    Fetch the region from AWS metadata store.
    """
    url = urlparse.urljoin(url, "/".join([version, params]))
    result = retry_url(url)
    return result[:-1].strip()


def get_iam_role(url=metadata_server, version="latest",
                 params="meta-data/iam/security-credentials/"):
    """
    Read IAM role from AWS metadata store.
    """
    url = urlparse.urljoin(url, "/".join([version, params]))
    result = retry_url(url)
    if result is None:
        # print "No IAM role found in the machine"
        return None
    else:
        return result


def get_credentials_from_iam_role(url=metadata_server,
                                  version="latest",
                                  params="meta-data/iam/security-credentials/",
                                  iam_role=None):
    """
    Read IAM credentials from AWS metadata store.
    """
    url = urlparse.urljoin(url, "/".join([version, params, iam_role]))
    result = retry_url(url)
    if result is None:
        # print "No IAM credentials found in the machine"
        return None
    try:
        data = json.loads(result)
    except ValueError as e:
        # print "Corrupt data found in IAM credentials"
        return None

    access_key = data.get('AccessKeyId', None)
    secret_key = data.get('SecretAccessKey', None)
    token = data.get('Token', None)

    if access_key and secret_key and token:
        return (access_key.encode("utf-8"),
                secret_key.encode("utf-8"),
                token.encode("utf-8"))
    else:
        return None


def init_hook(conduit):
    """
    Setup the S3 repositories
    """
    corrupt_repos = []
    s3_repos = {}

    repos = conduit.getRepos()
    for key, repo in repos.repos.iteritems():
        if isinstance(repo, YumRepository) and repo.enabled:
            if repo.baseurl and _check_s3_urls(repo.baseurl):
                s3_repos.update({key: repo})

    for key, repo in s3_repos.iteritems():
        try:
            new_repo = S3Repository(repo.id, repo, conduit)
        except IncorrectCredentialsError as e:
            # Credential Error is a general problem
            # will affect all S3 repos
            corrupt_repos = s3_repos.keys()
            break
        except Exception as e:
            corrupt_repos.append(key)
            continue

        # Correct yum repo on S3
        repos.delete(key)
        repos.add(new_repo)

    # Delete the incorrect yum repo on S3
    for repo in corrupt_repos:
        repos.delete(repo)


class S3Repository(YumRepository):

    """
    Repository object for Amazon S3
    """

    def __init__(self, repoid, repo, conduit):
        super(S3Repository, self).__init__(repoid)
        self.repoid = repoid
        self.conduit = conduit

        # FIXME: dirty code here
        self.__dict__.update(repo.__dict__)

        # Inherited from YumRepository <-- Repository
        self.enable()

        # Find the AWS Credentials
        self.set_credentials()

        # Disabled region initialization
        # self.set_region()

    def _getFile(self, url=None, relative=None, local=None,
                 start=None, end=None,
                 copy_local=None, checkfunc=None, text=None,
                 reget='simple', cache=True, size=None, **kwargs):
        """
        Patched _getFile func via AWS S3 REST API
        """
        mirrors = self.grab.mirrors
        # mirrors always exists as a list
        # and each element (dict) with a key named "mirror"
        for mirror in mirrors:
            baseurl = mirror["mirror"]
            super(S3Repository, self).grab.mirrors = [mirror]
            if _check_s3_urls(baseurl):
                region_name = get_region_from_s3url(baseurl)
                if region_name:
                    self.region = region_name
                self.http_headers = self.fetch_headers(baseurl, relative)
            else:
                # non-S3 URL
                self.http_headers = tuple(
                    self.__headersListFromDict(cache=cache))
            try:
                return super(S3Repository, self)._getFile(url, relative, local,
                                                          start, end,
                                                          copy_local,
                                                          checkfunc, text,
                                                          reget, cache,
                                                          size, **kwargs)
            except Exception as e:
                self.conduit.info(3, str(e))
                raise

    __get = _getFile

    def set_region(self):

        # Fetch params from local config file
        global timeout, retries, metadata_server
        timeout = self.conduit.confInt('aws', 'timeout', default=timeout)
        retries = self.conduit.confInt('aws', 'retries', default=retries)
        metadata_server = self.conduit.confString('aws',
                                                  'metadata_server',
                                                  default=metadata_server)

        # Fetch region from local config file
        self.region = self.conduit.confString('aws',
                                              'region',
                                              default=None)

        if self.region:
            return True

        # Fetch region from meta data
        region = get_region()
        if region is None:
            self.conduit.info(3, "[ERROR] No region in the plugin conf "
                                 "for the repo '%s'" % self.repoid)
            raise NoRegionError

        self.region = region
        return True

    def set_credentials(self):

        # Fetch params from local config file
        global timeout, retries, metadata_server
        timeout = self.conduit.confInt('aws', 'timeout', default=timeout)
        retries = self.conduit.confInt('aws', 'retries', default=retries)
        metadata_server = self.conduit.confString('aws',
                                                  'metadata_server',
                                                  default=metadata_server)

        # Fetch credentials from local config file
        self.access_key = self.conduit.confString('aws',
                                                  'access_key',
                                                  default=None)
        self.secret_key = self.conduit.confString('aws',
                                                  'secret_key',
                                                  default=None)
        self.token = self.conduit.confString('aws', 'token', default=None)
        if self.access_key and self.secret_key:
            return True

        # Fetch credentials from iam role meta data
        iam_role = get_iam_role()
        if iam_role is None:
            self.conduit.info(3, "[ERROR] No credentials in the plugin conf "
                                 "for the repo '%s'" % self.repoid)
            raise IncorrectCredentialsError

        credentials = get_credentials_from_iam_role(iam_role=iam_role)
        if credentials is None:
            self.conduit.info(3, "[ERROR] Fail to get IAM credentials"
                                 "for the repo '%s'" % self.repoid)
            raise IncorrectCredentialsError

        self.access_key, self.secret_key, self.token = credentials
        return True

    def fetch_headers(self, url, path):
        headers = {}

        # "\n" in the url, required by AWS S3 Auth v4
        url = urlparse.urljoin(url, urllib2.quote(path)) + "\n"
        credentials = Credentials(self.access_key, self.secret_key, self.token)
        request = HTTPRequest("GET", url)
        signer = S3SigV4Auth(credentials, "s3", self.region, self.conduit)
        signer.add_auth(request)
        return request.headers


if __name__ == '__main__':
    pass
