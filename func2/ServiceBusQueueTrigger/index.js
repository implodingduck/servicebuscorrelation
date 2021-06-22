module.exports = async function(context, mySbMsg) {
    context.log('JavaScript ServiceBus queue trigger function processed message', mySbMsg.body);
    context.log("Hello from func2 with correlationId: " + context.bindingData.correlationId)
    context.log("Hello from func2 with madeupId (should be undefined): " + context.bindingData.madeupId)
    context.log("Hello from func2 with messageId: " + context.bindingData.messageId)
    context.log("Hello from func2: " + JSON.stringify(context.bindingData))
};