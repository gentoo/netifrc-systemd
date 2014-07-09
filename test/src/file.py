from config import *

def save(key, value):
    with open(KEYSTORE, "a") as keystore:
        keystore.write("{} = {}\n".format(key, value))

def fetch(key):
    with open(KEYSTORE, "r") as keystore:
        for line in keystore:
            if(line.startswith(key + " = ")):
                val = line[line.index("=")+2:]
    return val.strip()
