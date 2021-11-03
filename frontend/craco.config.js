module.exports = {
  babel: {
    plugins: [["relay", { artifactDirectory: "./src/api/__generated__" }]],
  },
};
