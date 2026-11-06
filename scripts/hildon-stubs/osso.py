# Stand-in for the libosso bindings (python-osso) when a Maemo program runs on the PC (scripts/hildon-run.sh PY2=1).
# The real library connects to the Maemo system bus services that do not exist there. Only what programs usually
# need to start is provided; everything else is accepted and ignored.
class OssoException(Exception):
    pass


class Context(object):
    def __init__(self, application, version, activation=False):
        self.application = application
        self.version = version

    def close(self):
        pass


class Rpc(object):
    def __init__(self, context):
        self.context = context

    def __getattr__(self, name):
        return lambda *a, **k: None


class DeviceState(object):
    def __init__(self, context):
        pass

    def __getattr__(self, name):
        return lambda *a, **k: None


class Autosave(Rpc):
    pass


class StateSaving(Rpc):
    pass
