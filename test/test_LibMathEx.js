const assert = require('assert');
const BigNumber = require('bignumber.js');
const TestLibMathEx = artifacts.require('TestLibMathEx');
const { toWad, fromWad, shouldThrows, assertApproximate } = require("./utils.js");

contract('testLibMathEx', accounts => {

    let testLibMathEx;

    const deploy = async () => {
        testLibMathEx = await TestLibMathEx.new();
    };

    before(deploy);

    it("frac1", async () => {
        let r;
        let s;
        let c = "300000000000000";
        r = await testLibMathEx.wfracS("1111111111111111111", "500000000000000000", c);
        s = await testLibMathEx.wmulS("1111111111111111111", "500000000000000000");
        s = await testLibMathEx.wdivS(s.toString(), c);
        // A*B -> A*B +(-) 1E-18
        // A*B/C -> [A*B +(-) 1E-18]/C +(-) 1E-18 -> A*B/C +(-) 1E-18/C +(-) 1E-18
        // diff -> -(1E-18/C + 1E-18) ~ (1E-18/C + 1E-18)
        const diff = await testLibMathEx.wdivS(1, c);
        console.log("         R:", r.toString());
        console.log("         S:", s.toString());
        console.log("DIFF RANGE:", diff.toString());
        assert.ok(r.sub(s).abs() <= Number(diff.toString())) + 1;
    });

    it("frac2 neg", async () => {
        let r;
        let s;
        r = await testLibMathEx.wfracS("-1111111111111111111", "500000000000000000", "300000000000000000");
        s = await testLibMathEx.wmulS("-1111111111111111111", "500000000000000000");
        s = await testLibMathEx.wdivS(s.toString(), "300000000000000000");
        assert.ok(r.sub(s).abs() <= 1);
    });

    it("frac3 neg", async () => {
        let r;
        let s;
        r = await testLibMathEx.wfracS("1111111111111111111", "500000000000000000", "-300000000000000000");
        s = await testLibMathEx.wmulS("-1111111111111111111", "500000000000000000");
        s = await testLibMathEx.wdivS(s.toString(), "300000000000000000");
        assert.ok(r.sub(s).abs() <= 1);
    });

    it("abs", async () => {
        assert.equal((await testLibMathEx.absS(toWad(1.2))).toString(), toWad(1.2).toString());
        assert.equal((await testLibMathEx.absS(toWad(-1.2))).toString(), toWad(1.2).toString());
        await shouldThrows(testLibMathEx.absS('-57896044618658097711785492504343953926634992332820282019728792003956564819968'), 'overflow');
    });

    it("roundHalfUp", async () => {
        assert.equal((await testLibMathEx.roundHalfUpS(toWad(1.2), toWad(1))).toString(), toWad(1.7).toString());
        assert.equal((await testLibMathEx.roundHalfUpS(toWad(1.5), toWad(1))).toString(), toWad(2.0).toString());
        assert.equal((await testLibMathEx.roundHalfUpS(toWad(1.2344), toWad(0.001))).toString(), toWad(1.2349).toString());
        assert.equal((await testLibMathEx.roundHalfUpS(toWad(1.2345), toWad(0.001))).toString(), toWad(1.2350).toString());

        assert.equal((await testLibMathEx.roundHalfUpS(toWad(-1.2), toWad(1))).toString(), toWad(-1.7).toString());
        assert.equal((await testLibMathEx.roundHalfUpS(toWad(-1.5), toWad(1))).toString(), toWad(-2.0).toString());
        assert.equal((await testLibMathEx.roundHalfUpS(toWad(-1.2344), toWad(0.001))).toString(), toWad(-1.2349).toString());
        assert.equal((await testLibMathEx.roundHalfUpS(toWad(-1.2345), toWad(0.001))).toString(), toWad(-1.2350).toString());
    });

    it("unsigned wmul - trivial", async () => {
        // (2**128 - 1) * 1 = (2**128 - 1)
        assert.equal((await testLibMathEx.wmulU('340282366920938463463374607431768211455', toWad(1))).toString(), '340282366920938463463374607431768211455');
        assert.equal((await testLibMathEx.wmulU(toWad(0), toWad(0))).toString(), '0');
        assert.equal((await testLibMathEx.wmulU(toWad(0), toWad(1))).toString(), '0');
        assert.equal((await testLibMathEx.wmulU(toWad(1), toWad(0))).toString(), '0');
        assert.equal((await testLibMathEx.wmulU(toWad(1), toWad(1))).toString(), toWad(1).toString());
        assert.equal((await testLibMathEx.wmulU(toWad(1), toWad(0.2))).toString(), toWad(0.2).toString());
        assert.equal((await testLibMathEx.wmulU(toWad(2), toWad(0.2))).toString(), toWad(0.4).toString());
    });

    it("unsigned wmul - overflow", async () => {
        try {
            // 2**128 * 2**128
            await testLibMathEx.wmulU('340282366920938463463374607431768211456', '340282366920938463463374607431768211456');
            assert.fail('should overflow');
        } catch {
        }
    });

    it("unsigned wmul - rounding", async () => {
        assert.equal((await testLibMathEx.wmulU('1', '499999999999999999')).toString(), '0');
        assert.equal((await testLibMathEx.wmulU('1', '500000000000000000')).toString(), '1');
        assert.equal((await testLibMathEx.wmulU('950000000000005647', '1000000000')).toString(), '950000000');
        assert.equal((await testLibMathEx.wmulU('1000000000', '950000000000005647')).toString(), '950000000');
    });

    it("unsigned wdiv - trivial", async () => {
        assert.equal((await testLibMathEx.wdivU('0', toWad(1))).toString(), '0');
        assert.equal((await testLibMathEx.wdivU(toWad(1), toWad(1))).toString(), toWad(1).toString());
        assert.equal((await testLibMathEx.wdivU(toWad(1), toWad(2))).toString(), toWad(0.5).toString());
        assert.equal((await testLibMathEx.wdivU(toWad(2), toWad(2))).toString(), toWad(1).toString());
    });

    it("unsigned wdiv - div by 0", async () => {
        try {
            await testLibMathEx.wdivU(toWad(1), toWad(0));
            assert.fail('div by 0');
        } catch {
        }
    });

    it("unsigned wdiv - rounding", async () => {
        assert.equal((await testLibMathEx.wdivU('499999999999999999', '1000000000000000000000000000000000000')).toString(), '0');
        assert.equal((await testLibMathEx.wdivU('500000000000000000', '1000000000000000000000000000000000000')).toString(), '1');
        assert.equal((await testLibMathEx.wdivU(toWad(1), toWad(3))).toString(), '333333333333333333');
        assert.equal((await testLibMathEx.wdivU(toWad(2), toWad(3))).toString(), '666666666666666667');
        assert.equal((await testLibMathEx.wdivU(toWad(1), 3)).toString(), '333333333333333333333333333333333333');
        assert.equal((await testLibMathEx.wdivU(toWad(2), 3)).toString(), '666666666666666666666666666666666667');

    });

    it("signed wmul - trivial", async () => {
        // (2**128 - 1) * 1
        assert.equal((await testLibMathEx.wmulS('340282366920938463463374607431768211455', toWad(1))).toString(), '340282366920938463463374607431768211455');
        assert.equal((await testLibMathEx.wmulS(toWad(0), toWad(0))).toString(), '0');
        assert.equal((await testLibMathEx.wmulS(toWad(0), toWad(1))).toString(), '0');
        assert.equal((await testLibMathEx.wmulS(toWad(1), toWad(0))).toString(), '0');
        assert.equal((await testLibMathEx.wmulS(toWad(1), toWad(1))).toString(), toWad(1).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(1), toWad(0.2))).toString(), toWad(0.2).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(2), toWad(0.2))).toString(), toWad(0.4).toString());

        // (-2**128) * 1
        assert.equal((await testLibMathEx.wmulS('-340282366920938463463374607431768211456', toWad(1))).toString(), '-340282366920938463463374607431768211456');
        assert.equal((await testLibMathEx.wmulS(toWad(0), toWad(-1))).toString(), '0');
        assert.equal((await testLibMathEx.wmulS(toWad(-1), toWad(0))).toString(), '0');
        assert.equal((await testLibMathEx.wmulS(toWad(-1), toWad(1))).toString(), toWad(-1).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(1), toWad(-1))).toString(), toWad(-1).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(-1), toWad(-1))).toString(), toWad(1).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(1), toWad(-0.2))).toString(), toWad(-0.2).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(2), toWad(-0.2))).toString(), toWad(-0.4).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(-1), toWad(0.2))).toString(), toWad(-0.2).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(-2), toWad(0.2))).toString(), toWad(-0.4).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(-1), toWad(-0.2))).toString(), toWad(0.2).toString());
        assert.equal((await testLibMathEx.wmulS(toWad(-2), toWad(-0.2))).toString(), toWad(0.4).toString());
    });

    it("signed wmul - overflow", async () => {
        try {
            // 2**128 * 2**128
            await testLibMathEx.wmulS('340282366920938463463374607431768211456', '340282366920938463463374607431768211456');
            assert.fail('should overflow');
        } catch {
        }

        try {
            // -2**128 * -2**128
            await testLibMathEx.wmulS('-340282366920938463463374607431768211456', '-340282366920938463463374607431768211456');
            assert.fail('should overflow');
        } catch {
        }
    });

    it("signed wmul - rounding", async () => {
        assert.equal((await testLibMathEx.wmulS('1', '499999999999999999')).toString(), '0');
        assert.equal((await testLibMathEx.wmulS('1', '500000000000000000')).toString(), '1');
        assert.equal((await testLibMathEx.wmulS('950000000000005647', '1000000000')).toString(), '950000000');
        assert.equal((await testLibMathEx.wmulS('1000000000', '950000000000005647')).toString(), '950000000');

        assert.equal((await testLibMathEx.wmulS('-1', '499999999999999999')).toString(), '0');
        assert.equal((await testLibMathEx.wmulS('-1', '500000000000000000')).toString(), '-1');
        assert.equal((await testLibMathEx.wmulS('-950000000000005647', '1000000000')).toString(), '-950000000');
        assert.equal((await testLibMathEx.wmulS('-1000000000', '950000000000005647')).toString(), '-950000000');

        assert.equal((await testLibMathEx.wmulS('1', '-499999999999999999')).toString(), '0');
        assert.equal((await testLibMathEx.wmulS('1', '-500000000000000000')).toString(), '-1');
        assert.equal((await testLibMathEx.wmulS('950000000000005647', '-1000000000')).toString(), '-950000000');
        assert.equal((await testLibMathEx.wmulS('1000000000', '-950000000000005647')).toString(), '-950000000');

        assert.equal((await testLibMathEx.wmulS('-1', '-499999999999999999')).toString(), '0');
        assert.equal((await testLibMathEx.wmulS('-1', '-500000000000000000')).toString(), '1');
        assert.equal((await testLibMathEx.wmulS('-950000000000005647', '-1000000000')).toString(), '950000000');
        assert.equal((await testLibMathEx.wmulS('-1000000000', '-950000000000005647')).toString(), '950000000');
    });

    it("signed wdiv - trivial", async () => {
        assert.equal((await testLibMathEx.wdivS('0', toWad(1))).toString(), '0');
        assert.equal((await testLibMathEx.wdivS(toWad(1), toWad(1))).toString(), toWad(1).toString());
        assert.equal((await testLibMathEx.wdivS(toWad(1), toWad(2))).toString(), toWad(0.5).toString());
        assert.equal((await testLibMathEx.wdivS(toWad(2), toWad(2))).toString(), toWad(1).toString());

        assert.equal((await testLibMathEx.wdivS(toWad(-1), toWad(1))).toString(), toWad(-1).toString());
        assert.equal((await testLibMathEx.wdivS(toWad(-1), toWad(2))).toString(), toWad(-0.5).toString());
        assert.equal((await testLibMathEx.wdivS(toWad(-2), toWad(2))).toString(), toWad(-1).toString());

        assert.equal((await testLibMathEx.wdivS('0', toWad(-1))).toString(), '0');
        assert.equal((await testLibMathEx.wdivS(toWad(1), toWad(-1))).toString(), toWad(-1).toString());
        assert.equal((await testLibMathEx.wdivS(toWad(1), toWad(-2))).toString(), toWad(-0.5).toString());
        assert.equal((await testLibMathEx.wdivS(toWad(2), toWad(-2))).toString(), toWad(-1).toString());

        assert.equal((await testLibMathEx.wdivS(toWad(-1), toWad(-1))).toString(), toWad(1).toString());
        assert.equal((await testLibMathEx.wdivS(toWad(-1), toWad(-2))).toString(), toWad(0.5).toString());
        assert.equal((await testLibMathEx.wdivS(toWad(-2), toWad(-2))).toString(), toWad(1).toString());
    });

    it("signed wdiv - div by 0", async () => {
        try {
            await testLibMathEx.wdivS(toWad(1), toWad(0));
            assert.fail('div by 0');
        } catch {
        }
    });

    it("signed wdiv - rounding", async () => {
        assert.equal((await testLibMathEx.wdivS('499999999999999999', '1000000000000000000000000000000000000')).toString(), '0');
        assert.equal((await testLibMathEx.wdivS('500000000000000000', '1000000000000000000000000000000000000')).toString(), '1');
        assert.equal((await testLibMathEx.wdivS(toWad(1), toWad(3))).toString(), '333333333333333333');
        assert.equal((await testLibMathEx.wdivS(toWad(2), toWad(3))).toString(), '666666666666666667');
        assert.equal((await testLibMathEx.wdivS(toWad(1), 3)).toString(), '333333333333333333333333333333333333');
        assert.equal((await testLibMathEx.wdivS(toWad(2), 3)).toString(), '666666666666666666666666666666666667');

        assert.equal((await testLibMathEx.wdivS('-499999999999999999', '1000000000000000000000000000000000000')).toString(), '0');
        assert.equal((await testLibMathEx.wdivS('-500000000000000000', '1000000000000000000000000000000000000')).toString(), '-1');
        assert.equal((await testLibMathEx.wdivS(toWad(-1), toWad(3))).toString(), '-333333333333333333');
        assert.equal((await testLibMathEx.wdivS(toWad(-2), toWad(3))).toString(), '-666666666666666667');
        assert.equal((await testLibMathEx.wdivS(toWad(-1), 3)).toString(), '-333333333333333333333333333333333333');
        assert.equal((await testLibMathEx.wdivS(toWad(-2), 3)).toString(), '-666666666666666666666666666666666667');

        assert.equal((await testLibMathEx.wdivS('499999999999999999', '-1000000000000000000000000000000000000')).toString(), '0');
        assert.equal((await testLibMathEx.wdivS('500000000000000000', '-1000000000000000000000000000000000000')).toString(), '-1');
        assert.equal((await testLibMathEx.wdivS(toWad(1), toWad(-3))).toString(), '-333333333333333333');
        assert.equal((await testLibMathEx.wdivS(toWad(2), toWad(-3))).toString(), '-666666666666666667');
        assert.equal((await testLibMathEx.wdivS(toWad(1), -3)).toString(), '-333333333333333333333333333333333333');
        assert.equal((await testLibMathEx.wdivS(toWad(2), -3)).toString(), '-666666666666666666666666666666666667');

        assert.equal((await testLibMathEx.wdivS('-499999999999999999', '-1000000000000000000000000000000000000')).toString(), '0');
        assert.equal((await testLibMathEx.wdivS('-500000000000000000', '-1000000000000000000000000000000000000')).toString(), '1');
        assert.equal((await testLibMathEx.wdivS(toWad(-1), toWad(-3))).toString(), '333333333333333333');
        assert.equal((await testLibMathEx.wdivS(toWad(-2), toWad(-3))).toString(), '666666666666666667');
        assert.equal((await testLibMathEx.wdivS(toWad(-1), -3)).toString(), '333333333333333333333333333333333333');
        assert.equal((await testLibMathEx.wdivS(toWad(-2), -3)).toString(), '666666666666666666666666666666666667');
    });
});