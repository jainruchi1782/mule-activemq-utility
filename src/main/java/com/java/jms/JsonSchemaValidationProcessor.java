/**
 * 
 */
package com.test.validator;

import java.util.HashMap;
import java.util.Map;
import org.mule.api.MuleEvent;
import org.mule.api.MuleException;
import org.mule.api.processor.MessageProcessor;
import org.mule.module.json.validation.JsonSchemaDereferencing;
import org.mule.module.json.validation.JsonSchemaValidator;

import com.test.util.Constants;


/**
 * @author test
 *
 */
public class JsonSchemaValidationProcessor implements MessageProcessor {

	/*
	 * (non-Javadoc)
	 * 
	 * @see
	 * org.mule.api.processor.MessageProcessor#process(org.mule.api.MuleEvent)
	 */

	private static final String X_FLOW_VAR_SCHEMA_LOCATION = "SchemaName";

	private JsonSchemaDereferencing dereferencing = JsonSchemaDereferencing.CANONICAL;

	private Map<String, String> schemaRedirects = new HashMap<String, String>();

	private JsonSchemaValidator validator;
	
	public String exceptionString = Constants.EMPTY_STRING; 

	@Override
	public MuleEvent process(MuleEvent event) throws MuleException {
		// TODO Auto-generated method stub
		String schemaLocation = event.getFlowVariable(X_FLOW_VAR_SCHEMA_LOCATION);
		//schemaLocation = "/client/schema/"+schemaLocation;

		
		
		
		validator = JsonSchemaValidator.builder()

				.setSchemaLocation(schemaLocation)

				.setDereferencing(dereferencing)

				.addSchemaRedirects(schemaRedirects)

				.build();

		try {

			validator.validate(event);				
			event.setFlowVariable("IsSchemaValid", true);
		} catch (Exception e) {
			exceptionString = e.getMessage();
			int startIndex= exceptionString.indexOf("error:");
			int endIndex = exceptionString.indexOf("level: \"error\"");
			exceptionString = exceptionString.substring(startIndex, endIndex);
			event.setFlowVariable("SchemaError", exceptionString);
			event.setFlowVariable("IsSchemaValid", false);

		}
		return event;

	}
}
