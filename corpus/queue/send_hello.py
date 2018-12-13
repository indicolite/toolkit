import pika

'''
https://messeiry.com/openstack-rabbitmq-deep-dive/

'''
#connection = pika.BlockingConnection(pika.ConnectionParameters(host, port, virtual_host, credentials=pika.PlainCredentials(user, password)))
credentials = pika.PlainCredentials('admin', 'admin')
parameters = pika.ConnectionParameters('10.127.2.41',
                                   5672,
                                   '/',
                                   credentials)

connection = pika.BlockingConnection(parameters)
channel = connection.channel()

channel.queue_declare(queue='hello')
channel.basic_publish(exchange='', routing_key='hello', body='Hello World!')

print " [x] Sent 'Hello World!'"
connection.close()
