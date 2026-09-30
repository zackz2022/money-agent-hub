#!/bin/bash
set -e

echo "=================================="
echo "   MONEY AGENT HUB SETUP"
echo "=================================="

BASE="$HOME/money-agent-hub"
PLAT="$BASE/agent-platforms"

echo "[1/8] Creating folders..."
mkdir -p "$BASE/src/agents"
mkdir -p "$BASE/src/core"
mkdir -p "$PLAT"

echo "[2/8] Checking Node and npm..."
command -v node >/dev/null || {
  echo "Node.js is required."
  exit 1
}

command -v npm >/dev/null || {
  echo "npm is required."
  exit 1
}

echo "Node: $(node -v)"
echo "npm:  $(npm -v)"

echo "[3/8] Downloading BasedAgents..."
cd "$PLAT"
if [ ! -d basedagents ]; then
  git clone https://github.com/maxfain/basedagents
fi

echo "[4/8] Downloading MYA..."
if [ ! -d mya ]; then
  git clone https://github.com/monetizeyouragent-fun/mya
fi

echo "[5/8] Downloading gigs.sh..."
if [ ! -d gigs-sh ]; then
  git clone https://github.com/gigs-sh/gigs-sh
fi

echo "[6/8] Creating agents..."

cat > "$BASE/src/agents/basedagents.cjs" <<'EOF'
module.exports = {
  name: "BasedAgents",
  status: "ready",
  repository: "https://github.com/maxfain/basedagents"
};
EOF

cat > "$BASE/src/agents/mya.cjs" <<'EOF'
module.exports = {
  name: "MYA",
  status: "ready",
  repository: "https://github.com/monetizeyouragent-fun/mya"
};
EOF

cat > "$BASE/src/agents/gigs.cjs" <<'EOF'
const https = require("https");

const gigs = {};

gigs.name = "gigs.sh";
gigs.status = "connected";

gigs.getCategories = function () {
  return new Promise((resolve) => {
    https.get(
      "https://gigs.sh/api/v1/categories",
      (res) => {
        let data = "";

        res.on("data", chunk => {
          data += chunk;
        });

        res.on("end", () => {
          try {
            resolve(JSON.parse(data));
          } catch {
            resolve(null);
          }
        });
      }
    ).on("error", () => resolve(null));
  });
};

module.exports = gigs;
EOF

cat > "$BASE/src/agents/promotion.cjs" <<'EOF'
module.exports = {
  name: "Promotion Agent",
  status: "ready",
  purpose: "Promote approved digital products through legitimate channels."
};
EOF

echo "[7/8] Creating dashboard..."

cat > "$BASE/src/server.cjs" <<'EOF'
const http = require("http");

const basedagents = require("./agents/basedagents.cjs");
const mya = require("./agents/mya.cjs");
const gigs = require("./agents/gigs.cjs");
const promotion = require("./agents/promotion.cjs");

const agents = [
  basedagents,
  mya,
  gigs,
  promotion
];

const server = http.createServer(async (req, res) => {

  if (req.url === "/api/categories") {
    const categories = await gigs.getCategories();

    res.writeHead(200, {
      "Content-Type": "application/json"
    });

    res.end(JSON.stringify(categories || {
      error: "Unable to reach gigs.sh"
    }));

    return;
  }

  res.writeHead(200, {
    "Content-Type": "text/html"
  });

  const agentRows = agents.map(agent => `
    <div class="agent">
      <strong>${agent.name}</strong>
      <span>${agent.status}</span>
    </div>
  `).join("");

  res.end(`
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Money Agent Hub</title>

<style>
body {
  font-family: Arial, sans-serif;
  margin: 30px;
}

h1 {
  margin-bottom: 5px;
}

.agent {
  padding: 14px;
  margin: 10px 0;
  border: 1px solid #ccc;
  border-radius: 8px;
}

.agent span {
  margin-left: 15px;
}

button {
  padding: 10px 16px;
  margin-top: 15px;
  cursor: pointer;
}

#categories {
  margin-top: 20px;
  white-space: pre-wrap;
}
</style>
</head>

<body>

<h1>Money Agent Hub</h1>

<p>Four-agent control dashboard</p>

${agentRows}

<button onclick="scan()">Scan gigs.sh Categories</button>

<pre id="categories"></pre>

<script>
async function scan() {
  const box = document.getElementById("categories");
  box.textContent = "Scanning...";

  try {
    const response = await fetch("/api/categories");
    const data = await response.json();

    box.textContent = JSON.stringify(data, null, 2);
  } catch (error) {
    box.textContent = "Scan failed.";
  }
}
</script>

</body>
</html>
  `);
});

server.listen(3000, () => {
  console.log("");
  console.log("Money Agent Hub running:");
  console.log("http://localhost:3000");
  console.log("");
});
EOF

echo "[8/8] Creating start command..."

cat > "$BASE/start.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"

if pgrep -f "node src/server.cjs" >/dev/null; then
  echo "Money Agent Hub is already running."
  echo "Open http://localhost:3000"
  exit 0
fi

node src/server.cjs
EOF

chmod +x "$BASE/start.sh"

echo ""
echo "=================================="
echo "       SETUP COMPLETE"
echo "=================================="
echo ""
echo "Location:"
echo "$BASE"
echo ""
echo "Start the dashboard with:"
echo ""
echo "bash $BASE/start.sh"
echo ""
echo "Then open:"
echo "http://localhost:3000"
echo ""
echo "Agents:"
echo "1. BasedAgents"
echo "2. MYA"
echo "3. gigs.sh"
echo "4. Promotion Agent"
echo ""
