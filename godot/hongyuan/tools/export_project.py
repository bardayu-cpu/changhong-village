"""Temporary settings for a love-story export; leave the shared project unchanged."""
from contextlib import contextmanager
import re


@contextmanager
def love_project(root, wechat=False, user_data_name=None):
    project = root / 'project.godot'
    original = project.read_text()
    configured = original.replace('config/name="苏七镇奇缘"', 'config/name="红缘大冒险"')
    if user_data_name:
        configured = re.sub(r'^config/custom_user_dir_name=".*"$',
                            'config/custom_user_dir_name="' + user_data_name + '"',
                            configured, flags=re.M)
    # The estate needs the dialogue importer as well as the existing autoload.
    if wechat:
        section = re.search(r'(\[editor_plugins\]\s*\nenabled=PackedStringArray\()(.*?)(\))', configured)
        if not section:
            raise RuntimeError('Missing editor_plugins setting')
        plugins = section.group(2)
        for plugin in ('addons/dialogue_manager/plugin.cfg', 'addons/godot-minigame/plugin.cfg'):
            if plugin not in plugins:
                plugins += (', ' if plugins.strip() else '') + '"res://' + plugin + '"'
        configured = configured[:section.start(2)] + plugins + configured[section.end(2):]
    try:
        project.write_text(configured)
        yield
    finally:
        if project.read_text() != configured:
            raise RuntimeError('project.godot changed during export; inspect before restoring it')
        project.write_text(original)
