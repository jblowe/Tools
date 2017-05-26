#!/usr/bin/env /usr/bin/python
# -*- coding: UTF-8 -*-

import os
import sys
import ConfigParser

import time
import urllib2
import re
import base64

reload(sys)
sys.setdefaultencoding('utf-8')

timeoutcommand = "set statement_timeout to 240000; SET NAMES 'utf8';"

MAXLOCATIONS = 1000

try:
    import xml.etree.ElementTree as etree
    #print("running with ElementTree")
except ImportError:
    try:
        from lxml import etree
        #print("running with lxml.etree")
    except ImportError:
        try:
            # normal cElementTree install
            import cElementTree as etree
            #print("running with cElementTree")
        except ImportError:
            try:
                # normal ElementTree install
                import elementtree.ElementTree as etree
                #print("running with ElementTree")
            except ImportError:
                print("Failed to import ElementTree from any known place")


def getConfig(form):
    try:
        fileName = form.get('webapp') + '.cfg'
        config = ConfigParser.RawConfigParser()
        config.read(fileName)
        # test to see if it seems like it is really a config file
        logo = config.get('info', 'logo')
        return config
    except:
        return False

def make_get_request(realm, uri, server, username, password):
    """
        Makes HTTP GET request to a URL using the supplied username and password credentials.
    :rtype : a 3-tuple of the target URL, the data of the response, and an error code
    :param realm:
    :param uri:
    :param hostname:
    :param protocol:
    :param port:
    :param tenant:
    :param username:
    :param password:
    """

    elapsedtime = time.time()
    # if port == '':
    #     server = protocol + "://" + hostname
    # else:
    #     server = protocol + "://" + hostname + ":" + port

    # this is a bit elaborate because otherwise
    # the urllib2 approach to basicauth is to first try the request without the credentials, get a 401
    # then retry the request with the credentials... who know why...
    passMgr = urllib2.HTTPPasswordMgr()
    passMgr.add_password(realm, server, username, password)
    authhandler = urllib2.HTTPBasicAuthHandler(passMgr)
    opener = urllib2.build_opener(authhandler)
    unencoded_credentials = "%s:%s" % (username, password)
    auth_value = 'Basic %s' % base64.b64encode(unencoded_credentials).strip()
    opener.addheaders = [('Authorization', auth_value)]
    urllib2.install_opener(opener)
    url = "%s/cspace-services/%s" % (server, uri)

    try:
        f = urllib2.urlopen(url)
        statusCode = f.getcode()
        data = f.read()
        result = (url, data, statusCode)
    except urllib2.HTTPError, e:
        print 'The server (%s) couldn\'t fulfill the request.' % server
        print 'Error code: ', e.code
        result = (url, None, e.code)
    except urllib2.URLError, e:
        print 'We failed to reach the server (%s).' % server
        print 'Reason: ', e.reason
        result = (url, None, e.reason)
    except:
        raise
    
    return result #+ ((time.time() - elapsedtime),)


def postxml(requestType, uri, realm, server, username, password, payload):
    passman = urllib2.HTTPPasswordMgr()
    passman.add_password(realm, server, username, password)
    authhandler = urllib2.HTTPBasicAuthHandler(passman)
    opener = urllib2.build_opener(authhandler)
    urllib2.install_opener(opener)
    url = "%s/cspace-services/%s" % (server, uri)
    elapsedtime = 0.0

    elapsedtime = time.time()
    request = urllib2.Request(url, payload, {'Content-Type': 'application/xml'})
    # default method for urllib2 with payload is POST
    if requestType == 'PUT':
        request.get_method = lambda: 'PUT'
    else:
        request.get_method = lambda: 'POST'
    try:
        f = urllib2.urlopen(request)
    except urllib2.URLError, e:
        if hasattr(e, 'reason'):
            sys.stderr.write('We failed to reach a server.\n')
            sys.stderr.write('Reason: ' + str(e.reason) + '\n')
        if hasattr(e, 'code'):
            sys.stderr.write('The server couldn\'t fulfill the request.\n')
            sys.stderr.write('Error code: ' + str(e.code) + '\n')
        if True:
            #print 'Error in POSTing!'
            sys.stderr.write("Error in POSTing!\n")
            sys.stderr.write("%s\n" % url)
            sys.stderr.write(payload)
            raise

    data = f.read()
    info = f.info()
    # if a POST, the Location element contains the new CSID
    if info.getheader('Location'):
        csid = re.search(uri + '/(.*)', info.getheader('Location'))
        csid = csid.group(1)
    else:
        csid = ''
    elapsedtime = time.time() - elapsedtime
    return (url, data, csid, elapsedtime)


def relationsPayload(f):
    payload = """<?xml version="1.0" encoding="UTF-8"?>
<document name="relations">
  <ns2:relations_common xmlns:ns2="http://collectionspace.org/services/relation" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <relationshipType>affects</relationshipType>
    <objectCsid>%s</objectCsid>
    <objectDocumentType>%s</objectDocumentType>
    <subjectCsid>%s</subjectCsid>
    <subjectDocumentType>%s</subjectDocumentType>
  </ns2:relations_common>
</document>
"""
    payload = payload % (f['objectCsid'], f['objectDocumentType'], f['subjectCsid'], f['subjectDocumentType'])
    return payload
