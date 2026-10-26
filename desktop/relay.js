// Port relay: expose loopback-only services (LLM gateway, HTTP proxy, console)
// to the WSL/Docker network so containers can reach them.
//
// Every listener/target/port is overridable via environment variables. The
// default set matches a typical local Magpie gateway + console. Because these
// bridges re-expose loopback services onto a LAN-reachable interface, keep the
// host firewall scoped (see docs/SECURITY.md) or set WANG_RELAY_BIND to a
// narrower interface.
const net = require("net");

const BIND = process.env.WANG_RELAY_BIND || "0.0.0.0";

function parseRelays() {
  // WANG_RELAYS="name:listenPort:targetHost:targetPort,..."
  const spec =
    process.env.WANG_RELAYS ||
    "magpie:13425:127.0.0.1:3425,proxy:17897:127.0.0.1:7897,wang:18790:127.0.0.1:8790";
  return spec
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .map((s) => {
      const [name, listen, host, port] = s.split(":");
      return {
        name,
        listen: Number(listen),
        target: { host, port: Number(port) },
      };
    })
    .filter((r) => r.name && r.listen > 0 && r.target.host && r.target.port > 0);
}

for (const r of parseRelays()) {
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
  server.listen(r.listen, BIND, () => {
    console.log(
      `[relay ${r.name}] ${BIND}:${r.listen} -> ${r.target.host}:${r.target.port}`
    );
  });
}
