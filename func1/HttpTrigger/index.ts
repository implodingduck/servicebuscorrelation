import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { ServiceBusMessage } from "@azure/service-bus";

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log('JavaScript HTTP trigger function processed a request.');
    context.bindingData.correlationId = context.executionContext.invocationId
    context.log("Hello from func1 with correlationId: " + context.bindingData.correlationId)
    const name = context.executionContext.invocationId
    const responseMessage = name
        ? "Hello, " + name + ". This HTTP triggered function executed successfully."
        : "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.";

    context.bindings.res = {
        // status: 200, /* Defaults to 200 */
        body: responseMessage
    };
    const sbMsgArr: ServiceBusMessage[] = []
    sbMsgArr.push({
        body: "0 " + responseMessage,
        correlationId: context.executionContext.invocationId
    })
    sbMsgArr.push({
        body: "1 " + responseMessage,
        correlationId: context.executionContext.invocationId
    })
    sbMsgArr.push({
        body: "2 " + responseMessage,
        correlationId: context.executionContext.invocationId
    })
    context.bindings.mySbMsg = sbMsgArr

    context.done()
};

export default httpTrigger;