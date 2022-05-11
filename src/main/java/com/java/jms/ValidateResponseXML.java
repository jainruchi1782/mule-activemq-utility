package com.test.ms.filter;

import org.mule.api.MuleMessage;
import org.mule.api.routing.filter.Filter;
import org.xml.sax.SAXException;
import java.io.IOException;
import java.io.StringReader;
import javax.xml.transform.stream.StreamSource;
import javax.xml.validation.Schema;
import javax.xml.validation.SchemaFactory;
import javax.xml.validation.Validator;
import com.test.ms.util.Constants;


/**
 * @author SE2
 *
 */

public class ValidateResponseXML implements Filter {

	
	@Override
	public boolean accept(MuleMessage message) {
		// TODO Auto-generated method stub
		String payload = Constants.EMPTY_STRING;

		try {

			payload = message.getPayloadAsString();
			SchemaFactory schemaFactory = SchemaFactory.newInstance("http://www.w3.org/2001/XMLSchema");
			//Schema schema = schemaFactory.newSchema(new ValidateResponseXML().getClass().getClassLoader().getResource("xsd/TXLife2.22.00.xsd"));
			Schema schema = schemaFactory.newSchema(new ValidateResponseXML().getClass().getClassLoader().getResource("xsd/IWA.xsd"));
			Validator validator = schema.newValidator();
			validator.validate(new StreamSource(new StringReader(payload)));
			message.setInvocationProperty("isXMLValid", true);
			return true;
		} catch (SAXException e) {
			message.setInvocationProperty("isXMLValid", false);
			message.setInvocationProperty("errorMsg", e.getMessage());
			return true;
		} catch (IOException e) {
			message.setInvocationProperty("isXMLValid", false);
			message.setInvocationProperty("errorMsg", e.getMessage());
			return true;
		} catch (Exception e) {
			message.setInvocationProperty("isXMLValid", false);
			message.setInvocationProperty("errorMsg", e.getMessage());
			return true;
		}
	}
}
