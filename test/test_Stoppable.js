const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows } = require("./utils.js");
const { buildOrder } = require("./order.js");
const { getPerpetualComponents } = require("./perpetual.js");

const TestStoppable = artifacts.require('TestStoppable.sol');

contract('TestStoppable', accounts => {
    it("stop", async () => {
        var stoppable = await TestStoppable.new();
        assert.ok(!(await stoppable.stopped()));
        assert.ok(await stoppable.callableWhenNotStopped());
        await shouldThrows(stoppable.callableWhenStopped(), "Stoppable: not stopped");

        await stoppable.stop();
        assert.ok(await stoppable.stopped());
        await shouldThrows(stoppable.callableWhenNotStopped(), "Stoppable: stopped");
        assert.ok(await stoppable.callableWhenStopped());
    });
});
