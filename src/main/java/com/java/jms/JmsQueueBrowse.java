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
import javax.jms.Message;
import javax.jms.Queue;
import javax.jms.QueueBrowser;
import javax.jms.QueueSession;
import javax.jms.Session;
import javax.jms.TextMessage;
import org.apache.activemq.ActiveMQConnection;
import org.apache.activemq.ActiveMQConnectionFactory;
import org.apache.activemq.advisory.DestinationSource;
import org.apache.commons.collections.map.MultiValueMap;

public class JmsQueueBrowse implements Callable {
	@Override
	public MultiValueMap onCall(MuleEventContext eventContext) throws Exception {

		MuleMessage muleMessage = (DefaultMuleMessage) eventContext.getMessage();
		String queueName = muleMessage.getInboundProperty("queuename");
		String fromTime = muleMessage.getInboundProperty("fromtime");
		String toTime = muleMessage.getInboundProperty("totime");
		String environment = muleMessage.getInboundProperty("environment");

		MultiValueMap messages = new MultiValueMap();
		long beforeSend = 0;
		long afterSend = 0;
		String result = "";

		if(environment.equalsIgnoreCase("local"))
			result = "failover:(tcp://localhost:61616)?randomize=true&reconnectSupported=true";
		if(environment.equalsIgnoreCase("dev"))
			result = "failover:(tcp://hostname:61616)?randomize=true&reconnectSupported=true";
		if(environment.equalsIgnoreCase("qa"))
			result = "failover:(tcp://hostname:61616,tcp://hostname:61616)?randomize=true&reconnectSupported=true";
		
		ActiveMQConnectionFactory connectionFactory = new ActiveMQConnectionFactory(result);
		ActiveMQConnection connection = (ActiveMQConnection) connectionFactory.createConnection();

		try {

			DestinationSource ds = connection.getDestinationSource();

			QueueSession queueSession = connection.createQueueSession(true, Session.CLIENT_ACKNOWLEDGE);
			Queue queue = queueSession.createQueue(queueName);
			QueueBrowser browser = queueSession.createBrowser(queue);
			connection.start();
			Enumeration<?> messagesInQueue = browser.getEnumeration();

			if (fromTime != null || fromTime == "")
				beforeSend = Timestamp.valueOf(fromTime).getTime();
			if (toTime != null || toTime == "")
				afterSend = Timestamp.valueOf(toTime).getTime();

			while (messagesInQueue.hasMoreElements()) {
				Message queueMessage = (Message) messagesInQueue.nextElement();
				if (beforeSend != 0 && afterSend != 0) {
					if (queueMessage.getJMSTimestamp() >= beforeSend && queueMessage.getJMSTimestamp() <= afterSend) {
						if (queueMessage instanceof TextMessage) {
							TextMessage textMessage = (TextMessage) queueMessage;
							messages.put(queueMessage.getJMSCorrelationID(), textMessage.getText());
						}

					}
				} else if (beforeSend != 0 && afterSend == 0) {
					if (queueMessage.getJMSTimestamp() >= beforeSend && queueMessage.getJMSTimestamp() <= System.currentTimeMillis()) {
						if (queueMessage instanceof TextMessage) {
							TextMessage textMessage = (TextMessage) queueMessage;
							messages.put(queueMessage.getJMSCorrelationID(), textMessage.getText());
						}

					}
				} else {
					if (queueMessage instanceof TextMessage) {
						TextMessage textMessage = (TextMessage) queueMessage;
						messages.put(queueMessage.getJMSCorrelationID(), textMessage.getText());
					}
				}

			}

		} finally {
			if (connection != null) {
				connection.close();
			}
		}

		return messages;

	}
}
