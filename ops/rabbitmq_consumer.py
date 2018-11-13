#!/usr/bin/env python
import sys
import logging as log
from kombu import BrokerConnection
from kombu import Exchange
from kombu import Queue
from kombu.mixins import ConsumerMixin

EXCHANGE_NAME="nova"
ROUTING_KEY="notifications.info"
QUEUE_NAME="nova_dump_queue"
BROKER_URI="amqp://guest:guest@localhost:5672//"

log.basicConfig(stream=sys.stdout, level=log.DEBUG)

class NotificationsDump(ConsumerMixin):

    def __init__(self, connection):
        self.connection = connection
        return

    def get_consumers(self, consumer, channel):
        exchange = Exchange(EXCHANGE_NAME, type="topic", durable=False)
        queue = Queue(QUEUE_NAME, exchange, routing_key = ROUTING_KEY, durable=False, auto_delete=True, no_ack=True)
        return [ consumer(queue, callbacks = [ self.on_message ]) ]

    def on_message(self, body, message):
        log.info('Body: %r' % body)
        log.info('---------------')

if __name__ == "__main__":
    log.info("Connecting to broker {}".format(BROKER_URI))
    with BrokerConnection(BROKER_URI) as connection:
        NotificationsDump(connection).run()
