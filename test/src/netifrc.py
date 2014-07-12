#!/usr/bin/python3

import configparser
import os
import sys
import subprocess
from termcolor import colored
from yaml import load as yamlLoad

try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper


BASEDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), os.pardir))

config = configparser.ConfigParser()
config.read(os.path.join(BASEDIR, 'config.ini'))
defaults = config['GLOBALS']

from file import save as backend_save, fetch as backend_retrieve


def get_mode():
    if(os.path.exists("/var/run/openrc")):
        return defaults['MODE_MASTER']
    return defaults['MODE_SLAVE']


def normalize(*args):
    return '_'.join(''.join(c for c in arg if c.isalnum()) for arg in args)


def init(data):
    print(colored("Backing up {}".format(defaults['CONFIG_FILE']),
                  "yellow"))
    try:
        if(os.path.isfile(defaults['CONFIG_FILE'])):
            subprocess.check_call(["mv", defaults['CONFIG_FILE'],
                                   defaults['CONFIG_FILE_BACKUP']])

    except subprocess.CalledProcessError:
        print("Could not backup Config File")
        sys.exit(1)

    with open(BASEDIR + "/" + data['net_config'], 'r') as current_config_file:
        current_config = current_config_file.read()
    with open(defaults['CONFIG_FILE'], 'w') as config_file:
        config_file.write(current_config)

    try:
        subprocess.check_call(["rc-service", "net."+data['interface'],
                               "restart"])
    except subprocess.CalledProcessError:
        print("Could not effectively start process net."+data['interface'])
        sys.exit(1)


def finalize(data):
    print(colored("Restoring {}".format(defaults['CONFIG_FILE']),
                  'yellow'))
    try:
        subprocess.check_call(["mv",
                               defaults['CONFIG_FILE_BACKUP'],
                               defaults['CONFIG_FILE']])
    except subprocess.CalledProcessError:
        print("Could not Restore Config File")
        sys.exit(1)

    try:
        subprocess.check_call(["rc-service", "net."+data['interface'], "stop"])
    except subprocess.CalledProcessError:
        print("Could not effectively stop process net." + data['interface'])
        sys.exit(1)


def test(data, mode):
    print(colored(data['name'], 'green'))
    for test in data['tests']:
        print(colored("  {}: {}".format(test['name'], test['command']),
                      'green'))
        command = subprocess.Popen(test['command'], stdout=subprocess.PIPE,
                                   shell=True)
        try:
            (out, err) = command.communicate(timeout=int(defaults['TIMEOUT']))
        except subprocess.TimeoutExpired:
            print(colored("Command {} Expired".format(test['command']), 'red'))
            command.kill()
            command.communicate()
        else:
            for key in test['keys']:
                print(colored("    Extracting {}:".format(key['name']),
                              'green'), end=" ", flush=True)
                key_command = subprocess.Popen(key['value'],
                                               stdin=subprocess.PIPE,
                                               stdout=subprocess.PIPE,
                                               shell=True)
                try:
                    (stdout, stderr) = key_command.communicate(
                        input=out,
                        timeout=int(defaults['TIMEOUT']))

                except subprocess.TimeoutExpired:
                    print(colored("Trying to find the value of {} timed out"
                                  .format(key['name']), 'red'))
                    key_command.kill()
                    key_command.communicate()

                else:
                    if('type' in key and key['type'] == "boolean"):
                        value = str(key_command.returncode)
                    else:
                        value = stdout.decode("utf-8").strip()

                    print(colored(value, 'green'), end=" ", flush=True)

                    if(mode == defaults['MODE_MASTER']):
                        backend_save(normalize(data['name'],
                                               test['name'],
                                               key['name']), value)
                        print()
                    else:
                        backend_value = backend_retrieve(
                            normalize(data['name'], test['name'], key['name']))
                        try:
                            assert value == backend_value
                        except AssertionError:
                            print(colored("[ FAIL ]", 'red'))
                            err = "    Backend value {} does not match {}"
                            print(colored(err.format(backend_value, value),
                                          'red'))
                            sys.exit(1)
                        else:
                            print(colored("[ PASS ]", 'green'))


for file in sys.argv[1:]:
    with open(file, 'r') as f:
        document = f.read()

    # Replace with the variables defined in SPECS
    for var in config['SPECS']:
        document = document.replace("$${}$$".format(var.upper()),
                                    config['SPECS'][var])

    # Parse the yaml file
    data = yamlLoad(document, Loader=Loader)

    try:
        mode = os.environ['MODE']
    except KeyError:
        mode = ""

    if(mode != defaults['MODE_MASTER'] and mode != defaults['MODE_SLAVE']):
        mode = get_mode()

    try:
        init(data)
        test(data, mode=mode)
    finally:
        finalize(data)
