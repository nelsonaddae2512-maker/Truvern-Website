const { createCanvas } = require("canvas");
const fs = require("fs");
const W = 1200, H = 630;
const canvas = createCanvas(W, H);
const ctx = canvas.getContext("2d");

// background
ctx.fillStyle = "#f6f8fb";
ctx.fillRect(0,0,W,H);

// rounded dark badge
ctx.fillStyle = "#111827";
ctx.beginPath();
ctx.moveTo(80, 80);
ctx.lineTo(W-80, 80);
ctx.lineTo(W-80, H-80);
ctx.lineTo(80, H-80);
ctx.closePath();
ctx.fill();

// heading
ctx.fillStyle = "#fff";
ctx.font = "bold 86px system-ui, Segoe UI, Roboto, Helvetica, Arial";
ctx.fillText("Truvern", 120, 220);
ctx.font = "bold 52px system-ui, Segoe UI, Roboto, Helvetica, Arial";
ctx.fillText("Trust your vendors. Move faster.", 120, 320);

// sub
ctx.font = "32px system-ui, Segoe UI, Roboto, Helvetica, Arial";
ctx.fillStyle = "#d1d5db";
ctx.fillText("truvern.com", 120, 420);

// save
const out = fs.createWriteStream("public/opengraph-image.png");
const stream = canvas.createPNGStream();
stream.pipe(out);
out.on("finish", () => console.log("OG image written -> public/opengraph-image.png"));
