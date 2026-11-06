# Stand-in for the libconic bindings (Maemo Internet connection API) for programs run by scripts/hildon-run.sh on the PC.
# The real module talks to the connection daemon of the phone. Here the PC network is "always connected", a WLAN.
BEARER_WLAN_INFRA = "WLAN_INFRA"
BEARER_WLAN_ADHOC = "WLAN_ADHOC"
BEARER_GPRS = "GPRS"
CONNECT_FLAG_NONE = 0
CONNECT_FLAG_AUTOMATICALLY_TRIGGERED = 1
CONNECT_FLAG_UNMANAGED = 2
STATUS_CONNECTED = 0
STATUS_DISCONNECTED = 1
STATUS_DISCONNECTING = 2


class Iap(object):
    def get_id(self):
        return "emulator"

    def get_name(self):
        return "PC network"

    def get_bearer_type(self):
        return BEARER_WLAN_INFRA


class Connection(object):
    def __init__(self):
        self.handlers = []

    def connect(self, signal, handler, *args):
        self.handlers.append((signal, handler, args))
        return len(self.handlers)

    def request_connection(self, flags=0):
        return True

    def get_iap(self, iap_id=None):
        return Iap()

    def get_all_iaps(self):
        return [Iap()]

    def __getattr__(self, name):
        return lambda *a, **k: None


class ConnectionEvent(object):
    def get_status(self):
        return STATUS_CONNECTED

    def get_iap_id(self):
        return "emulator"
