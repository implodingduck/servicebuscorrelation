module.exports = async function (context, req) {
    context.log('JavaScript HTTP trigger function processed a request.');
    context.bindingData.correlationId = context.executionContext.invocationId
    context.bindings.correlationId = context.executionContext.invocationId
    context.log("Hello from func1 with correlationId: " + context.bindingData.correlationId)
    const name = context.executionContext.invocationId
    const responseMessage = name
        ? "Hello, " + name + ". This HTTP triggered function executed successfully."
        : "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.";

    context.res = {
        // status: 200, /* Defaults to 200 */
        body: responseMessage
    };
    context.bindings.mySbMsg = {
        body: responseMessage,
        correlationId: context.executionContext.invocationId
    }
    context.bindings.httpResponse = {
        body: responseMessage
    }
    context.done()
    return
}