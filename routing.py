import re

from wards.wards_service import WardsService
from properties.properties_service import PropertiesService
from stats.stats_service import StatsService
from alerts.alerts_service import AlertsService
from chat.chat_service import ChatService
from admin.admin_service import AdminService

_wards = WardsService()
_props = PropertiesService()
_stats = StatsService()
_alerts = AlertsService()
_chat = ChatService()
_admin = AdminService()

# (METHOD, path_pattern, handler, param_names)
ROUTES = [
    ("GET",  "/api/wards",                                     _wards.list_wards,      []),
    ("GET",  r"/api/wards/(?P<wardId>[^/]+)/changes",           _wards.get_changes,     ["wardId"]),
    ("GET",  r"/api/wards/(?P<wardId>[^/]+)/unassessed",        _props.list_for_ward,   ["wardId"]),
    ("GET",  r"/api/wards/(?P<wardId>[^/]+)/alerts",            _alerts.list_for_ward,  ["wardId"]),

    ("GET",  r"/api/properties/(?P<id>[^/]+)",                  _props.get_detail,      ["id"]),
    ("POST", r"/api/properties/(?P<id>[^/]+)/verify",           _props.verify,          ["id"]),

    ("GET",  "/api/stats/all-wards",                            _stats.get_all_wards,   []),
    ("GET",  "/api/stats",                                      _stats.get_stats,       []),

    ("POST", "/api/alerts/export",                              _alerts.export,         []),

    ("POST", "/api/chat",                                       _chat.send,             []),

    ("POST", "/api/admin/upload-csv",                           _admin.upload_csv,      []),
    ("POST", "/api/admin/db-config",                             _admin.save_db_config,  []),
    ("POST", "/api/admin/refresh",                               _admin.trigger_refresh, []),
]


def dispatch_rest(method, path, obj, connection):
    for route_method, pattern, handler_fn, param_names in ROUTES:
        if route_method != method:
            continue
        m = re.fullmatch(pattern, path)
        if m:
            for name in param_names:
                obj[name] = m.group(name)
            return handler_fn(obj, connection)

    raise ValueError(f"Route not found: {method} {path}")
