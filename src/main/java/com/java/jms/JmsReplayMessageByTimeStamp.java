/**
 * 
 */
package com.java.jms;

import org.mule.DefaultMuleMessage;

/**
 * @author mishra3
 *
 */

import org.mule.api.MuleEventContext;
import org.mule.api.MuleMessage;
import org.mule.api.lifecycle.Callable;
import java.sql.Timestamp;
import java.util.Enumeration;
import javax.jms.DeliveryMode;
import javax.jms.Message;
import javax.jms.MessageConsumer;
import javax.jms.MessageProducer;
import javax.jms.Queue;
import javax.jms.QueueBrowser;
import javax.jms.QueueSession;
import javax.jms.Session;
import javax.jms.TextMessage;
import org.apache.activemq.ActiveMQConnection;
import org.apache.activemq.ActiveMQConnectionFactory;
import org.apache.commons.collections.map.MultiValueMap;

public class JmsReplayMessageByTimeStamp implements Callable {
	@Override
	public MultiValueMap onCall(MuleEventContext eventContext) throws Exception {

		MuleMessage muleMessage = (DefaultMuleMessage) eventContext.getMessage();
		String dlqQueueName = muleMessage.getInboundProperty("dlqqueuename");
		String queueName = muleMessage.getInboundProperty("queuename");
		String environment = muleMessage.getInboundProperty("environment");
		String fromTime = muleMessage.getInboundProperty("fromtime");
		String toTime = muleMessage.getInboundProperty("totime");
		String ClientCode = muleMessage.getInboundProperty("clientcode");
		String TransactionName = muleMessage.getInboundProperty("transactionname");
		String selectorexpression = muleMessage.getInboundProperty("selectorexpression");

		MultiValueMap messages = new MultiValueMap();
		long beforeSend = 0;
		long afterSend = 0;
		String result = "";

		if (environment.equalsIgnoreCase("local"))
			result = "failover:(tcp://localhost:61616)?randomize=true&reconnectSupported=true";
		if (environment.equalsIgnoreCase("dev"))
			result = "failover:(tcp://hostname:61616)?randomize=true&reconnectSupported=true";
		if (environment.equalsIgnoreCase("qa"))
			result = "failover:(tcp://hostname:61616,tcp://hostname:61616)?randomize=true&reconnectSupported=true";

		ActiveMQConnectionFactory connectionFactory = null;
		ActiveMQConnection connection = null;

		QueueSession queueSession = null;
		Queue dlqqueue = null;
		Queue queue = null;

		MessageConsumer consumer = null;
		MessageProducer producer = null;

		TextMessage dlqTextMessage = null;
		TextMessage message = null;

		QueueBrowser dlqbrowser = null;
		try {

			connectionFactory = new ActiveMQConnectionFactory(result);
			connection = (ActiveMQConnection) connectionFactory.createConnection();

			if (fromTime != null || fromTime == "")
				beforeSend = Timestamp.valueOf(fromTime).getTime();
			if (toTime != null || toTime == "")
				afterSend = Timestamp.valueOf(toTime).getTime();

			connection.start();

			// Create a session with DLQ and queue
			queueSession = connection.createQueueSession(false, Session.AUTO_ACKNOWLEDGE);

			dlqqueue = queueSession.createQueue(dlqQueueName);
			if (selectorexpression != null)
				dlqbrowser = queueSession.createBrowser(dlqqueue, selectorexpression);
			else {
				selectorexpression = "(JMSTimestamp BETWEEN " + beforeSend + " AND " + afterSend + ") AND (ClientCode = '" + ClientCode + "') AND (Transaction = '" + TransactionName + "')" ;
				System.out.println("selectorexpression " + selectorexpression);
				dlqbrowser = queueSession.createBrowser(dlqqueue, selectorexpression);
				
			}
				

			Enumeration<?> messagesInQueue = dlqbrowser.getEnumeration();

			queue = queueSession.createQueue(queueName);

			// Create a MessageConsumer from the Session to the Topic or Queue

			consumer = queueSession.createConsumer(dlqqueue);

			// Create a MessageProducer from the Session to the Queue
			producer = queueSession.createProducer(queue);
			producer.setDeliveryMode(DeliveryMode.NON_PERSISTENT);

			while (messagesInQueue.hasMoreElements()) {
				Message dlqqueueMessage = consumer.receive();

				if (dlqqueueMessage instanceof TextMessage) {
					dlqTextMessage = (TextMessage) dlqqueueMessage;
					message = queueSession.createTextMessage(dlqTextMessage.getText());

					@SuppressWarnings("unchecked")
					Enumeration<String> srcProperties = dlqTextMessage.getPropertyNames();

					while (srcProperties.hasMoreElements()) {
						String propertyName = srcProperties.nextElement();
						message.setObjectProperty(propertyName, dlqTextMessage.getObjectProperty(propertyName));
					}

					// message.setObjectProperty("JMSDestination",
					// dlqTextMessage.getJMSDestination());
					// message.setObjectProperty("JMSReplyTo", dlqTextMessage.getJMSReplyTo());
					message.setObjectProperty("JMSType", dlqTextMessage.getJMSType());
					message.setObjectProperty("JMSDeliveryMode", dlqTextMessage.getJMSDeliveryMode());
					message.setObjectProperty("JMSPriority", dlqTextMessage.getJMSPriority());
					message.setObjectProperty("JMSMessageID", dlqTextMessage.getJMSMessageID());
					message.setObjectProperty("JMSTimestamp", dlqTextMessage.getJMSTimestamp());
					message.setObjectProperty("JMSCorrelationID", dlqTextMessage.getJMSCorrelationID());
					message.setObjectProperty("JMSExpiration", dlqTextMessage.getJMSExpiration());
					message.setObjectProperty("JMSRedelivered", dlqTextMessage.getJMSRedelivered());

					producer.send(message);

				} else {
					System.out.println("Received: " + dlqqueueMessage);
				}
				messages.put(dlqqueueMessage.getJMSCorrelationID(), dlqTextMessage.getText());
				messagesInQueue.nextElement();
			}

		} catch (Exception e) {
			System.out.println("Caught: " + e);
			e.printStackTrace();
		} finally {
			consumer.close();
			queueSession.close();
			connection.close();
		}

		return messages;

	}
}
