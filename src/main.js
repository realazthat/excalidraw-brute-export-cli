#!/usr/bin/env node
import playwright from "playwright";
import caporal from "@caporal/core";
import path from "path";
const { program } = caporal;
import { fileURLToPath } from "url";
import { cwd } from "node:process";
import { mkdir } from "fs/promises";

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
  try {
    console.log("console.log('amain')");
    logger.info("logger.info('amain')");
    logger.info("options:", options);

    const t0 = Date.now();

    const input /*: string */ = options.input;
    const output /*: string */ = options.output;
    const port /*: number */ = options.port;
    const excalidrawURL = options.url;
    const outputFileName = path.basename(output);

    let screenshotsPath = "";
    if (options.screenshots) {
      screenshotsPath = path.resolve(cwd(), options.screenshots);
    }

    // Have to use firefox, because chromium doesn't let us easily intercept the
    // file upload API that Excalidraw uses.
    const browser = await playwright.firefox.launch({
      headless: options.headless,
    });
    const context = await browser.newContext();
    const page = await context.newPage();
    page.on("console", (msg) => logger.info(msg.text()));

    // Set screen size
    // await page.setViewport({ width: 1024, height: 1024 });
    await PupTakeScreenshot({ page, screenshotsPath });

    // Navigate the page to a URL
    await page.goto(excalidrawURL);
    await new Promise((resolve) => setTimeout(resolve, 1));
    await PupTakeScreenshot({ page, screenshotsPath });

    const fileChooserPromise = page.waitForEvent("filechooser");

    await page.keyboard.press("Control+O");
    await new Promise((resolve) => setTimeout(resolve, 100));
    await PupTakeScreenshot({ page, screenshotsPath });

    logger.info("OK file is chosen?");

    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(input);
    logger.info("fileChooserPromise!");
    await new Promise((resolve) => setTimeout(resolve, 100));
    await PupTakeScreenshot({ page, screenshotsPath });

    await page.keyboard.press("Control+Shift+E");
    await new Promise((resolve) => setTimeout(resolve, 100));
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
    await new Promise((resolve) => setTimeout(resolve, 100));
    await PupTakeScreenshot({ page, screenshotsPath });
    //////////////////////////////////////////////////////////////////////////////
    const fileDownloadPromise = page.waitForEvent("download");

    if (options.format === "svg") {
      await saveSVG.click();
    } else if (options.format === "png") {
      await savePNG.click();
    }

    const fileDownload = await fileDownloadPromise;
    await fileDownload.saveAs(output);

    logger.info("fileChooserPromise!");
    await new Promise((resolve) => setTimeout(resolve, 100));
    await PupTakeScreenshot({ page, screenshotsPath });
    //////////////////////////////////////////////////////////////////////////////

    logger.info("closing...");
    await page.close();
    await browser.close();
    const t1 = Date.now();

    const delta = t1 - t0;
    const deltaSeconds = delta / 1000;
    logger.info(`Took ${deltaSeconds.toFixed(2)} seconds.`);
  } catch (e) {
    logger.error("Error:", e);
    process.exit(1);
  }
}

program
  .bin("excalidraw-brute-export-cli")
  .version("0.1.0")
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
  .option("--headless [headless]", "Should the browser be headless.", {
    validator: program.BOOLEAN,
    default: true,
  })
  .option(
    "--screenshots [screenshots]",
    "Path to store debug screenshots at each step. Empty string means no screenshots are recored. Defaults to no screenshots.",
    {
      validator: program.STRING,
      default: "",
    },
  )
  .action(({ args, options, logger }) => {
    return amain({ options, logger });
  })
  .run()
  .then(() => {
    console.log("program.run() done");
    process.exit(0);
  })
  .catch((e) => {
    console.error("program.run() failed:", e);
    process.exit(1);
  });
