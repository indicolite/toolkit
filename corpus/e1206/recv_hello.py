import pika

#connection = pika.BlockingConnection(pika.ConnectionParameters(host, port, virtual_host, credentials=pika.PlainCredentials(user, password)))
credentials = pika.PlainCredentials('admin', 'admin')
parameters = pika.ConnectionParameters('10.127.2.41',
                                   5672,
                                   '/',
                                   credentials)

connection = pika.BlockingConnection(parameters)
channel = connection.channel()

channel.queue_declare(queue='hello')
print ' [*] Waiting for messages. To exit press CTRL+C'

def callback(ch, method, properties, body):
    print " [x] Received %r" % (body,)

channel.basic_consume(callback, queue='hello', no_ack=True)
channel.start_consuming()
