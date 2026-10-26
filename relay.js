// Magpie/代理端口中继：WSL NAT 侧经宿主机网关 IP 访问仅监听 127.0.0.1 的本机服务
const net = require("net");

const relays = [
  { listen: 13425, target: { host: "127.0.0.1", port: 3425 }, name: "magpie" },
  { listen: 17897, target: { host: "127.0.0.1", port: 7897 }, name: "proxy" },
  { listen: 18790, target: { host: "127.0.0.1", port: 8790 }, name: "wang" },
];

for (const r of relays) {
  const server = net.createServer((client) => {
    const upstream = net.connect(r.target.port, r.target.host, () => {});
    client.pipe(upstream);
    upstream.pipe(client);
    const kill = () => {
      client.destroy();
      upstream.destroy();
    };
    client.on("error", kill);
    upstream.on("error", kill);
    client.on("close", kill);
    upstream.on("close", kill);
  });
  server.on("error", (e) => {
    console.error(`[relay ${r.name}] listen error:`, e.message);
    process.exitCode = 1;
  });
  server.listen(r.listen, "0.0.0.0", () => {
    console.log(`[relay ${r.name}] 0.0.0.0:${r.listen} -> 127.0.0.1:${r.target.port}`);
  });
}
