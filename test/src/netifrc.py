#!/usr/bin/python3

import yaml
import os
import sys
import subprocess

try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper


from config import *
BASEDIR = os.path.normpath(os.path.join(os.path.dirname( __file__), os.pardir))

from file import save as backend_save, fetch as backend_retrieve

def get_mode():
    if(os.path.exists("/var/run/openrc")):
        return MODE_MASTER
    return MODE_SLAVE

def normalize(*args):
    return '_'.join(''.join(c for c in arg if c.isalnum()) for arg in args)

def init(data):
    print("Backing up {}".format(CONFIG_FILE))
    try:
        if(os.path.isfile(CONFIG_FILE)):
            subprocess.check_call(["mv", CONFIG_FILE, CONFIG_FILE_BACKUP])
    except subprocess.CalledProcessError:
        print("Could not backup Config File")
        sys.exit(1)

    with open(BASEDIR + "/" + data['net_config'], 'r') as current_config_file:
        current_config = current_config_file.read()
    with open(CONFIG_FILE, 'w') as config_file:
        config_file.write(current_config)

    try:
        subprocess.check_call(["rc-service", "net."+data['interface'], "restart"])
    except subprocess.CalledProcessError:
        print("Could not effectively start process net."+data['interface'])
        sys.exit(1)

def finalize(data):
    print("Restoring {}".format(CONFIG_FILE))
    try:
        subprocess.check_call(["mv", CONFIG_FILE_BACKUP, CONFIG_FILE])
    except subprocess.CalledProcessError:
        print("Could not Restore Config File")
        sys.exit(1)

    try:
        subprocess.check_call(["rc-service", "net."+data['interface'], "stop"])
    except subprocess.CalledProcessError:
        print("Could not effectively stop process net." + data['interface'])
        sys.exit(1)

def test(data, mode):
    for test in data['tests']:
        print(test['name'])
        command = subprocess.Popen(test['command'], stdout=subprocess.PIPE, shell=True)
        try:
            (out, err) = command.communicate(timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            print("Command {} Expired".format(test['command']))
            command.kill()
            command.communicate()
        else:
            for key in test['keys']:
                key_command = subprocess.Popen(key['value'],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, shell=True)
                try:
                    (stdout, stderr) = key_command.communicate(input=out, timeout=TIMEOUT)
                except subprocess.TimeoutExpired:
                    print("Trying to find the value of {} timed out".format(key['name']))
                    key_command.kill()
                    key_process.communicate()
                else:
                    if('type' in key and key['type'] == "boolean"):
                        value = str(key_command.returncode)
                    else:
                        value = stdout.decode("utf-8").strip()
                    #print("{} is {}".format(key['name'],value))
                    if(mode == MODE_MASTER):
                        backend_save(normalize(data['name'], test['name'], key['name']), value)
                    else:
                        backend_value = backend_retrieve(normalize(data['name'], test['name'], key['name']))
                        print("{} {}".format(value, backend_value))
                        assert value == backend_value

for file in sys.argv[1:]:
    with open(file, 'r') as f:
        document = f.read()
    data = yaml.load(document, Loader=Loader)
    try:
        mode = os.environ['MODE']
    except KeyError:
        mode = ""
    if(mode != MODE_MASTER and mode != MODE_SLAVE):
        mode = get_mode()
    try:
        init(data)
        test(data, mode=mode)
    finally:
        finalize(data)
