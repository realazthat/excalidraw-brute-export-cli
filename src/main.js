#!/usr/bin/env node
import playwright from "playwright";
import caporal from "@caporal/core";
import path from "path";
const { program } = caporal;
import { fileURLToPath } from "url";
import { cwd } from "node:process";
import { mkdir } from "fs/promises";
import { version } from "../lib/version.js";

// get the resolved path to the file
const __filename = fileURLToPath(import.meta.url);
// get the name of the directory
// From: https://iamwebwiz.medium.com/how-to-fix-dirname-is-not-defined-in-es-module-scope-34d94a86694d
const __dirname = path.dirname(__filename);

let screenShotIndex = 0;

async function PupTakeScreenshot({ page, screenshotsPath }) {
  if (screenshotsPath === "") {
    return;
  }
  await mkdir(screenshotsPath, { recursive: true });

  screenShotIndex += 1;
  await page.screenshot({
    path: path.resolve(screenshotsPath, `screenshot.${screenShotIndex}.png`),
    type: "png",
  });
}

async function amain({ options, logger }) {
  console.log("console.log('amain')");
  logger.info("logger.info('amain')");
  logger.info("options:", options);

  if (options.leaveBrowserRunning && options.headless) {
    throw new Error(
      "leave-browser-running can only be used when headless is false.",
    );
  }

  const input /*: string */ = options.input;
  const output /*: string */ = options.output;
  const excalidrawURL = options.url;
  const outputFileName = path.basename(output);
  const actionsSleepTime = options.actionSleepTime;

  let screenshotsPath = "";
  if (options.screenshots) {
    screenshotsPath = path.resolve(cwd(), options.screenshots);
  }

  let page = null;
  try {
    // Have to use firefox, because chromium doesn't let us easily intercept the
    // file upload API that Excalidraw uses.
    const browser = await playwright.firefox.launch({
      headless: options.headless,
      leaveBrowserRunning: options.leaveBrowserRunning,
    });
    const context = await browser.newContext();
    page = await context.newPage();
    if (options.timeout >= 0) {
      page.setDefaultTimeout(options.timeout);
    }
    page.on("console", (msg) => logger.info(msg.text()));

    // Set screen size
    // await page.setViewport({ width: 1024, height: 1024 });
    await PupTakeScreenshot({ page, screenshotsPath });

    // Navigate the page to a URL
    await page.goto(excalidrawURL);
    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });

    const fileChosenPromise = new Promise((resolve, reject) => {
      page.once("filechooser", async (fileChooser) => {
        try {
          await fileChooser.setFiles(input);
          logger.info("File is chosen!");
          resolve();
        } catch (e) {
          reject(e);
        }
      });
    });

    logger.info("Opening file: Control+O");
    await page.keyboard.press("Control+O");
    logger.info("Choosing file");

    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });

    await fileChosenPromise;

    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });

    await page.keyboard.press("Control+Shift+E");
    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });

    //////////////////////////////////////////////////////////////////////////////
    // Fill in the export form.
    const exportBackgroundSwitch = page.locator("#exportBackgroundSwitch");
    const exportDarkModeSwitch = page.locator("#exportDarkModeSwitch");
    const exportEmbedSwitch = page.locator("#exportEmbedSwitch");
    const exportScaleElements = page.locator('input[name="exportScale"]');
    const exportFileName = page.locator(".ImageExportModal input.TextInput");
    const savePNG = page.locator("button[aria-label='Export to PNG']");
    const saveSVG = page.locator("button[aria-label='Export to SVG']");
    const copyToClipboard = page.locator(
      "button[aria-label='Copy PNG to clipboard']",
    );

    if (options.background) {
      await exportBackgroundSwitch.check();
    } else {
      await exportBackgroundSwitch.uncheck();
    }

    if (options.darkMode) {
      await exportDarkModeSwitch.check();
    } else {
      await exportDarkModeSwitch.uncheck();
    }

    if (options.embedScene) {
      await exportEmbedSwitch.check();
    } else {
      await exportEmbedSwitch.uncheck();
    }

    logger.info(
      `await exportScaleElements.count(): ${await exportScaleElements.count()}`,
    );

    const scale2Element = {};
    for (const scaleChoiceElement of await exportScaleElements.all()) {
      let scale = (
        await scaleChoiceElement.locator("xpath=..").textContent()
      ).trim();
      if (scale.endsWith("×")) {
        scale = scale.slice(0, -1);
      }
      scale2Element[scale] = scaleChoiceElement;
    }

    if (!scale2Element.hasOwnProperty(options.scale)) {
      throw new Error(
        `Invalid scale: ${JSON.stringify(options.scale)}, valid scales are: {${Object.keys(scale2Element).join(", ")}}`,
      );
    } else {
      const scaleElement = scale2Element[options.scale];
      await scaleElement.click();
    }

    await exportFileName.fill(outputFileName);
    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });
    //////////////////////////////////////////////////////////////////////////////

    const fileDownloadedPromise = new Promise((resolve, reject) => {
      page.once("download", async (fileDownload) => {
        try {
          await fileDownload.saveAs(output);
          logger.info("File is downloaded!");
          resolve();
        } catch (e) {
          reject(e);
        }
      });
    });

    if (options.format === "svg") {
      logger.info("Pressing SVG button!");
      await saveSVG.click();
    } else if (options.format === "png") {
      logger.info("Pressing PNG button!");
      await savePNG.click();
    }

    await fileDownloadedPromise;

    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });
    //////////////////////////////////////////////////////////////////////////////
    if (options.leaveBrowserRunning) {
      logger.info("Leaving browser running. Press Ctrl+C to exit.");
      await new Promise(() => {});
    }
    logger.info("closing...");
    await page.close();
    await browser.close();
  } catch (e) {
    logger.error("Error:", e);
    if (page !== null && screenshotsPath !== "") {
      logger.info("Taking screenshot before exiting due to error");
      await PupTakeScreenshot({ page, screenshotsPath });
    }

    if (options.leaveBrowserRunning) {
      logger.info("Leaving browser running. Press Ctrl+C to exit.");
      await new Promise(() => {});
    }
    process.exit(1);
  }
}

program
  .bin("excalidraw-brute-export-cli")
  .version(version)
  .description(
    "Export Excalidraw using a (headless) browser via the command line.",
  )
  .option("-i, --input <excalidaraw-path>", "The path to the excalidraw file", {
    validator: program.STRING,
    required: true,
  })
  .option(
    "-b, --background <background>",
    "Should the background be exported, or should it be transparent. Same option as in the Excalidraw UI when exporting an image.",
    { validator: program.BOOLEAN, required: true },
  )
  .option(
    "-d, --dark-mode <dark-mode>",
    "Should the diagram be exported in dark mode, or not. Same option as in the Excalidraw UI when exporting an image.",
    { validator: program.BOOLEAN, required: true },
  )
  .option(
    "-e, --embed-scene <embed-scene>",
    "Should the diagram be exported with the scene embedded in the image, or not. Tooltip from the UI: 'Scene data will be saved into the exported PNG/SVG file so that the scene can be restored from it.\nWill increase exported file size.' Same option as in the Excalidraw UI when exporting an image.",
    { validator: program.BOOLEAN, required: true },
  )
  .option(
    "-s, --scale <scale>",
    "The scale to use when exporting the image. Same option as in the Excalidraw UI when exporting an image.",
    { validator: [1, 2, 3], required: true },
  )
  .option(
    "-f, --format <format>",
    'The format to export the image in. Either "png" or "svg".',
    {
      validator: ["png", "svg"],
      required: true,
    },
  )
  .option("-o, --output <output-path>", "The path to the output file.", {
    validator: program.STRING,
    required: true,
  })
  .option("-u, --url [url]", "The URL to use for excalidraw website.", {
    validator: program.STRING,
    default: "https://excalidraw.com/",
  })
  .option(
    "--headless [headless]",
    "Should the browser be headless. Note that file dialogs do not open/work. Can turn this off for debugging.",
    {
      validator: program.BOOLEAN,
      default: true,
    },
  )
  .option(
    "--leave-browser-running [leave-browser-running]",
    "Should the browser be left open afterwards (only allowed when headless==false). Can turn this off for debugging.",
    {
      validator: program.BOOLEAN,
      default: false,
    },
  )
  .option(
    "--screenshots [screenshots]",
    "Path to store debug screenshots at each step. Empty string means no screenshots are recorded. Defaults to no screenshots.",
    {
      validator: program.STRING,
      default: "",
    },
  )
  .option(
    "--action-sleep-time [action-sleep-time]",
    "Time (in milliseconds) for each action to sleep in playwright. Defaults to 100. Too short and dialogs won't open. Too long and it will take longer to run.",
    {
      validator: program.INTEGER,
      default: 100,
    },
  )
  .option(
    "--timeout [timeout]",
    "Timeout (in milliseconds) for each action in playwright. 0 for infinite timeout. -1 for no specific timeout, which uses playwright's default timeout. Defaults to -1.",
    {
      validator: program.INTEGER,
      default: -1,
    },
  )
  .action(({ args, options, logger }) => {
    return amain({ options, logger });
  })
  .run()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error("program.run() failed:", e);
    process.exit(1);
  });
