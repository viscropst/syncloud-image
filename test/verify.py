#!/usr/bin/env python
import logging
import convertible
import pytest
import requests

from syncloud.app import logger
from syncloud.insider.facade import get_insider
from syncloud.sam.manager import get_sam
from syncloud.sam.pip import Pip
from syncloud.server.serverfacade import get_server


@pytest.fixture(scope="session", autouse=True)
def activate_device(auth):

    logger.init(logging.DEBUG, True)

    Pip(None).log_version('syncloud-platform')

    # persist upnp mock setting
    get_insider().insider_config.set_upnpc_mock(True)

    server = get_server(insider=get_insider(use_upnpc_mock=True))
    release = open('RELEASE', 'r').read().strip()
    email, password = auth
    server.activate(release, 'syncloud.info', 'http://api.syncloud.info:81', email, password, 'teamcity', 'user', 'password')

    # request.addfinalizer(finalizer_function)


def test_server():
    session = requests.session()
    response = session.get('http://localhost/server/rest/user', allow_redirects=False)
    print(response.text)
    assert response.status_code == 302
    response = session.post('http://localhost/server/rest/login', data={'name': 'user', 'password': 'password'})
    print(response.text)
    assert session.get('http://localhost/server/rest/user', allow_redirects=False).status_code == 200


def test_owncloud():
    sam = get_sam()
    sam.install('syncloud-owncloud')
    from syncloud.owncloud import facade
    owncloud = facade.get_control(get_insider(use_upnpc_mock=True))
    owncloud.finish('test', 'test', 'localhost', 'http')
    assert owncloud.verify('localhost')


# def test_imageci():
    # sam = get_sam()
    # sam.install('syncloud-image-ci')
    # from syncloud.ci.facade import ImageCI
    # image_ci = ImageCI(insider)
    # image_ci.activate()
    # assert image_ci.verify()


# def test_gitbucket():
#     sam = get_sam()
#     sam.install('syncloud-gitbucket')
#     from syncloud.gitbucketctl.facade import GitBucketControl
#     gitbucket = GitBucketControl(get_insider())
#     gitbucket.enable('travis', 'password')
#     assert gitbucket.verify()