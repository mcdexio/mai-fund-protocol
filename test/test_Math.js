const assert = require("assert");
const BN = require('bn.js');

const TestMath = artifacts.require('TestMath.sol');

contract('TestMath', accounts => {

    var math;

    const deploy = async () => {
        math = await TestMath.new();
    }

    before(deploy);

    it("abs", async () => {
        assert.equal(await math.abs(-555), 555);
        assert.equal(await math.abs(555), 555);
        assert.equal(await math.abs(0), 0);
        try {
            await math.abs("0x8000000000000000000000000000000000000000000000000000000000000000");
            throw null;
        } catch (error) {
            assert.ok(error.message.includes("subtraction overflow"));
        }
    });

    it("neg", async () => {
        assert.equal(await math.neg(-555), 555);
        assert.equal(await math.neg(555), -555);
        assert.equal(await math.neg(0), 0);
        try {
            await math.neg("0x8000000000000000000000000000000000000000000000000000000000000000");
            throw null;
        } catch (error) {
            assert.ok(error.message.includes("subtraction overflow"));
        }
    });
});


