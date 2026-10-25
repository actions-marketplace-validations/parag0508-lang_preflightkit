# INTENTIONALLY INSECURE test fixture — do not copy.
import pickle, subprocess

def load(data):
    return pickle.loads(data)

def convert(name):
    subprocess.run("convert " + name + " out.png", shell=True)

API_KEY = "fake-placeholder-not-a-real-key"
