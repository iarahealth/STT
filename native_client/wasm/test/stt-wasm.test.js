import STT from "@iarastt/stt-wasm";

describe("STT WASM", () => {
  it("Checks stt-wasm was imported", () => {
    expect(STT).toBeDefined();
  });
  it.skip("Instantiates correctly the module", async () => {
    let ready = false;
    let instance = await STT({
      locateFile: (filename) => {
        if (filename == "stt_wasm.worker.js") {
          return `${__dirname}/mock.worker.js`;
        }
        return `${__dirname}/node_modules/@iarastt/stt-wasm/dist/${filename}`;
      },
    });
    expect(ready).toBeTrue();
    expect(instance).toBeDefined();
  });
});
