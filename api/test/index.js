const chai = require('chai')
const { Lib } = require("../lib")

const { expect } = chai

describe('#lib', function () {

    let lib 

    before(function () {
        lib = new Lib()
    })

    it('should get hello success ', async () => {

        const output = await lib.getTest() 

        expect(output).to.equal("hello")
    })

})