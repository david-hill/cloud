#!/usr/bin/env python
#
# Copyright (c) 2016 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

"""
Utility to recover a damaged resource from the database.

Offers a number of commands to manipulate resource statuses and move resources
back and forth between the backup stack and the main stack.

Like heat-manage, this needs to run on the same machine as heat-engine and as
either the heat or root users (in order to be able to access heat's config).

Author: Zane Bitter <zbitter@redhat.com>
"""

from oslo_config import cfg

from heat.engine import stack
from heat.engine import update

from heat.objects import stack as stack_object


CONF = cfg.CONF


def _load_stack(ctx, stack_id):
    s = stack_object.Stack.get_by_id(ctx, stack_id)
    if s is None:
        return None
    return stack.Stack.load(ctx, stack=s, service_check_defer=True)


def _load_backup(main_stack):
    for s in stack_object.Stack.get_all_by_owner_id(main_stack.context,
                                                    main_stack.id):
        if s.name == main_stack._backup_name():
            return stack.Stack.load(main_stack.context, stack=s,
                                    service_check_defer=True)

    return None


def _load_stack_and_backup(ctx, stack_id):
    main = _load_stack(ctx, stack_id)
    backup = _load_backup(main)

    return main, backup


def _get_stack_resource_status(stack):
    if stack is None:
        return None
    return {r.name: '_'.join(r.state) for r in stack.values()}


def get_resource_statuses(ctx, stack_id):
    return map(_get_stack_resource_status,
               _load_stack_and_backup(ctx, stack_id))


def swap_backup(ctx, stack_id, resource_name):
    main, backup = _load_stack_and_backup(ctx, stack_id)
    update.StackUpdate._exchange_stacks(main[resource_name],
                                        backup[resource_name])


def _change_resource_status(ctx, stack_id, resource_name, new_status,
                            cancel_delete=False):
    main = _load_stack(ctx, stack_id)
    resource = main[resource_name]
    if cancel_delete and resource.action == resource.DELETE:
        action = resource.UPDATE
    else:
        action = resource.action
    resource.state_set(action, getattr(resource, new_status),
                       'Recovery utility')


def mark_complete(ctx, stack_id, resource_name, cancel_delete=False):
    _change_resource_status(ctx, stack_id, resource_name, 'COMPLETE',
                            cancel_delete=cancel_delete)


def mark_failed(ctx, stack_id, resource_name):
    _change_resource_status(ctx, stack_id, resource_name, 'FAILED')


ctxt = None


def cmd_get_resource_statuses():
    stack_id = CONF.command.stack_id

    main_statuses, backup_statuses = get_resource_statuses(ctxt,
                                                           stack_id)

    def format_statuses(statuses):
        if statuses is None:
            return '(Stack does not exist)'
        return '\n'.join('  %15s: %s' % i for i in sorted(statuses.items()))

    print('Main stack (%s):\n%s' % (stack_id, format_statuses(main_statuses)))
    print('Backup stack:\n%s' % format_statuses(backup_statuses))


def cmd_swap_backup():
    stack_id = CONF.command.stack_id
    resource_name = CONF.command.resource_name

    swap_backup(ctxt, stack_id, resource_name)
    cmd_get_resource_statuses()


def cmd_cancel_delete():
    stack_id = CONF.command.stack_id
    resource_name = CONF.command.resource_name

    mark_complete(ctxt, stack_id, resource_name, cancel_delete=True)
    cmd_get_resource_statuses()


def cmd_mark_complete():
    stack_id = CONF.command.stack_id
    resource_name = CONF.command.resource_name

    mark_complete(ctxt, stack_id, resource_name)
    cmd_get_resource_statuses()


def cmd_mark_failed():
    stack_id = CONF.command.stack_id
    resource_name = CONF.command.resource_name

    mark_failed(ctxt, stack_id, resource_name)
    cmd_get_resource_statuses()


def add_command_parsers(subparsers):
    parser = subparsers.add_parser('get_resource_statuses')
    parser.set_defaults(func=cmd_get_resource_statuses)
    parser.add_argument('stack_id', nargs='?')

    parser = subparsers.add_parser('swap_backup')
    parser.set_defaults(func=cmd_swap_backup)
    parser.add_argument('stack_id', nargs='?')
    parser.add_argument('resource_name', nargs='?')

    parser = subparsers.add_parser('mark_complete')
    parser.set_defaults(func=cmd_mark_complete)
    parser.add_argument('stack_id', nargs='?')
    parser.add_argument('resource_name', nargs='?')

    parser = subparsers.add_parser('cancel_delete')
    parser.set_defaults(func=cmd_cancel_delete)
    parser.add_argument('stack_id', nargs='?')
    parser.add_argument('resource_name', nargs='?')

    parser = subparsers.add_parser('mark_failed')
    parser.set_defaults(func=cmd_mark_failed)
    parser.add_argument('stack_id', nargs='?')
    parser.add_argument('resource_name', nargs='?')


def main():
    import sys

    from heat.common import context
    from heat import version

    command_opt = cfg.SubCommandOpt('command',
                                    title='Commands',
                                    help='Show available commands',
                                    handler=add_command_parsers)
    CONF.register_cli_opt(command_opt)

    try:
        default_config_files = cfg.find_config_files('heat', 'heat-engine')
        CONF(sys.argv[1:], project='heat', prog='heat-recover',
             version=version.version_info.version_string(),
             default_config_files=default_config_files)
    except RuntimeError as e:
        sys.exit("ERROR: %s" % e)

    global ctxt
    ctxt = context.get_admin_context()

    CONF.command.func()


if __name__ == '__main__':
    main()

