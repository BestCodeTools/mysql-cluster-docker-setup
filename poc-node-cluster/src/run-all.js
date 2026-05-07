const path = require("path");
const { spawn } = require("child_process");

function runProcess(command, args, label) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: "inherit",
      shell: false
    });

    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${label} falhou com codigo ${code}.`));
    });

    child.on("error", reject);
  });
}

function runNodeScript(relativePath, label) {
  const absolutePath = path.resolve(__dirname, relativePath);

  return runProcess(process.execPath, [absolutePath], label);
}

function runKnexMigration() {
  const knexCliPath = path.resolve(__dirname, "..", "node_modules", "knex", "bin", "cli.js");
  const knexfilePath = path.resolve(__dirname, "..", "knexfile.cjs");

  return runProcess(
    process.execPath,
    [knexCliPath, "--knexfile", knexfilePath, "migrate:latest"],
    "migrate"
  );
}

async function main() {
  const steps = [
    {
      label: "db:prepare",
      run: () => runNodeScript("./prepare-database.js", "db:prepare")
    },
    {
      label: "migrate",
      run: () => runKnexMigration()
    },
    {
      label: "sequelize:check",
      run: () => runNodeScript("./sequelize-check.js", "sequelize:check")
    },
    {
      label: "verify",
      run: () => runNodeScript("./verify-ndb-table.js", "verify")
    }
  ];

  for (const step of steps) {
    console.log(`\n==> Executando ${step.label}`);
    await step.run();
  }
}

main().catch((error) => {
  console.error("Falha no fluxo completo:", error.message);
  process.exit(1);
});
