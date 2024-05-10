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

const VALID_EXCALIDRAW_VERSIONS = ["0.15.0", "0.17.0"];

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

// Abstract away some selectors that are different between Excalidraw versions.
class Locators {
  constructor({ page, excalidrawVersion }) {
    this.page = page;
    this.excalidrawVersion = excalidrawVersion;
    if (!VALID_EXCALIDRAW_VERSIONS.includes(excalidrawVersion)) {
      throw new Error(
        `Invalid excalidrawVersion: ${excalidrawVersion}, valid versions are: ${VALID_EXCALIDRAW_VERSIONS.join(
          ", ",
        )}`,
      );
    }
  }

  mainMenuTrigger() {
    if (this.excalidrawVersion == "0.15.0") {
      return this.page.locator("button.dropdown-menu-button");
    }
    return this.page.locator("button.main-menu-trigger");
  }
}

async function OpenFileDialog({
  locators,
  page,
  logger,
  actionsSleepTime,
  screenshotsPath,
}) {
  logger.info("Clicking: Menu Burger");
  const mainMenuTrigger = locators.mainMenuTrigger();
  await mainMenuTrigger.click();
  await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
  await PupTakeScreenshot({ page, screenshotsPath });

  logger.info("Clicking: Open Menu Item");
  const openButton = page.locator("button[aria-label='Open']");
  await openButton.click();
  await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
  await PupTakeScreenshot({ page, screenshotsPath });

  // This is not good, because it is OS dependent (Mac uses some other combo).
  //
  // logger.info("Opening file: Control+O");
  // await page.keyboard.press("Control+O");
  // await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
  // await PupTakeScreenshot({ page, screenshotsPath });
}

async function OpenExportModal({
  locators,
  page,
  logger,
  actionsSleepTime,
  screenshotsPath,
}) {
  const exportButton = page.locator("button[aria-label='Export image...']");

  if ((await exportButton.count()) === 0) {
    logger.info("Clicking: Menu Burger");
    const mainMenuTrigger = locators.mainMenuTrigger();
    await mainMenuTrigger.click();
    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });
  }

  logger.info("Clicking: Export Menu Item");
  await exportButton.click();
  await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
  await PupTakeScreenshot({ page, screenshotsPath });

  // This is not good, because it is OS dependent (Mac uses some other combo).
  //
  // logger.info("Opening export modal: Control+Shift+E");
  // await page.keyboard.press("Control+Shift+E");
  // await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
  // await PupTakeScreenshot({ page, screenshotsPath });
}

// For Excalidraw v0.15.0
async function FillInExportForm15({
  logger,
  page,
  outputFileName,
  background,
  darkMode,
  embedScene,
  scale,
}) {
  // <button aria-checked="true" />
  const exportBackgroundSwitch = page.locator(
    `xpath=//div[contains(@class, 'Checkbox') and .//div[@class='Checkbox-label' and normalize-space(text())='Background']]/button[@role='checkbox']`,
  );
  // <button aria-checked="true" />
  const exportEmbedSwitch = page.locator(
    `xpath=//div[contains(@class, 'Checkbox') and .//div[@class='Checkbox-label' and normalize-space(text())='Embed scene']]/button[@role='checkbox']`,
  );

  const exportDarkModeToggle = page.locator(
    "button[aria-label='Toggle export color scheme']",
  );

  async function DetectDarkMode() {
    const path = exportDarkModeToggle.locator("path");
    const d = await path.getAttribute("d");
    if (d.startsWith("M283.211 ")) {
      // The dark mode symbol is being shown, but that means we are in light
      // mode.
      return false;
    }
    if (d.startsWith("M256 ")) {
      // The light mode symbol is being shown, but that means we are in dark
      // mode.
      return true;
    }
    throw new Error(`Failed to detect dark mode`);
  }

  // const exportScaleElements = page.locator(`xpath=//input[@name="export-canvas-scale"]/parent:*`);
  const exportScaleDiv = page.locator(
    `xpath=//div[contains(@class, 'ExportDialog')]//p[normalize-space(text())='Scale']/..`,
  );
  const exportScaleElements = exportScaleDiv.locator(
    `xpath=//div[contains(@class, 'ToolIcon__icon')]`,
  );
  logger.info(
    `await exportBackgroundSwitch.count(): ${await exportBackgroundSwitch.count()}`,
  );
  logger.info(
    `await exportEmbedSwitch.count(): ${await exportEmbedSwitch.count()}`,
  );
  logger.info(`await exportScaleDiv.count(): ${await exportScaleDiv.count()}`);
  logger.info(
    `await exportScaleElements.count(): ${await exportScaleElements.count()}`,
  );
  const exportFileName = page.locator(".ProjectName input.TextInput");

  if (background) {
    await exportBackgroundSwitch.check();
  } else {
    await exportBackgroundSwitch.uncheck();
  }

  if (darkMode != (await DetectDarkMode())) {
    await exportDarkModeToggle.click();
    if (darkMode != (await DetectDarkMode())) {
      throw new Error("Failed to toggle dark mode");
    }
  }

  if (embedScene) {
    await exportEmbedSwitch.check();
  } else {
    await exportEmbedSwitch.uncheck();
  }

  const scale2Element = {};
  for (const scaleChoiceElement of await exportScaleElements.all()) {
    let scale = (
      await scaleChoiceElement.locator("xpath=..").textContent()
    ).trim();
    if (scale.endsWith("x")) {
      scale = scale.slice(0, -1);
    }
    scale2Element[scale] = scaleChoiceElement;
  }

  if (!scale2Element.hasOwnProperty(scale)) {
    throw new Error(
      `Invalid scale: ${JSON.stringify(scale)}, valid scales are: {${Object.keys(scale2Element).join(", ")}}`,
    );
  } else {
    const scaleElement = scale2Element[scale];
    await scaleElement.click();
  }

  await exportFileName.fill(outputFileName);
}

async function FillInExportForm17({
  logger,
  page,
  outputFileName,
  background,
  darkMode,
  embedScene,
  scale,
}) {
  // Fill in the export form.
  const exportBackgroundSwitch = page.locator("#exportBackgroundSwitch");
  const exportDarkModeSwitch = page.locator("#exportDarkModeSwitch");
  const exportEmbedSwitch = page.locator("#exportEmbedSwitch");
  const exportScaleElements = page.locator('input[name="exportScale"]');
  const exportFileName = page.locator(".ImageExportModal input.TextInput");

  if (background) {
    await exportBackgroundSwitch.check();
  } else {
    await exportBackgroundSwitch.uncheck();
  }

  if (darkMode) {
    await exportDarkModeSwitch.check();
  } else {
    await exportDarkModeSwitch.uncheck();
  }

  if (embedScene) {
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

  if (!scale2Element.hasOwnProperty(scale)) {
    throw new Error(
      `Invalid scale: ${JSON.stringify(scale)}, valid scales are: {${Object.keys(scale2Element).join(", ")}}`,
    );
  } else {
    const scaleElement = scale2Element[scale];
    await scaleElement.click();
  }

  await exportFileName.fill(outputFileName);
}

async function DetectExcalidrawVersion({ page }) {
  if ((await page.locator("button.main-menu-trigger").count()) > 0) {
    return "0.17.0";
  } else {
    return "0.15.0";
  }
}

async function amain({ options, logger }) {
  logger.info("options:", options);

  if (options.leaveBrowserRunning && options.headless) {
    throw new Error(
      "leave-browser-running can only be used when headless is false.",
    );
  }

  const input /*: string */ = options.input;
  const output /*: string */ = options.output;
  let excalidrawURL = options.url;
  if (excalidrawURL === undefined || excalidrawURL === "") {
    logger.info(
      "Falling back to environment variable EXCALIDRAW_BRUTE_EXPORT_CLI_URL",
    );
    excalidrawURL = process.env.EXCALIDRAW_BRUTE_EXPORT_CLI_URL;
  }
  if (excalidrawURL === undefined || excalidrawURL === "") {
    logger.info("Falling back to default URL: https://excalidraw.com/");
    excalidrawURL = "https://excalidraw.com/";
  }
  logger.info(`excalidrawURL: ${excalidrawURL}`);

  let excalidrawVersion = options.excalidrawVersion;
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
    page.on("console", (msg) => logger.debug(msg.text()));

    // Set screen size
    // await page.setViewport({ width: 1024, height: 1024 });
    await PupTakeScreenshot({ page, screenshotsPath });

    // Navigate the page to a URL
    await page.goto(excalidrawURL);
    await page.waitForLoadState("domcontentloaded");
    await page.waitForLoadState("load");
    await page.waitForLoadState("networkidle");
    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });

    if (excalidrawVersion === "") {
      logger.info("Detecting Excalidraw version...");
      excalidrawVersion = await DetectExcalidrawVersion({ page });
    }
    logger.info(`excalidrawVersion: ${excalidrawVersion}`);
    const locators = new Locators({ page, excalidrawVersion });

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

    await OpenFileDialog({
      locators,
      page,
      logger,
      actionsSleepTime,
      screenshotsPath,
    });
    await fileChosenPromise;

    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });

    await OpenExportModal({
      locators,
      page,
      logger,
      actionsSleepTime,
      screenshotsPath,
    });

    await new Promise((resolve) => setTimeout(resolve, actionsSleepTime));
    await PupTakeScreenshot({ page, screenshotsPath });
    //////////////////////////////////////////////////////////////////////////////

    if (excalidrawVersion === "0.17.0") {
      await FillInExportForm17({
        logger,
        page,
        outputFileName,
        background: options.background,
        darkMode: options.darkMode,
        embedScene: options.embedScene,
        scale: options.scale,
      });
    } else {
      await FillInExportForm15({
        logger,
        page,
        outputFileName,
        background: options.background,
        darkMode: options.darkMode,
        embedScene: options.embedScene,
        scale: options.scale,
      });
    }

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

    const savePNG = page.locator("button[aria-label='Export to PNG']");
    const saveSVG = page.locator("button[aria-label='Export to SVG']");
    const copyToClipboard = page.locator(
      "button[aria-label='Copy PNG to clipboard']",
    );
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
  .option(
    "-u, --url [url]",
    "The URL to use for excalidraw website. Falls back to environment variable EXCALIDRAW_BRUTE_EXPORT_CLI_URL if not specified. Falls back to https://excalidraw.com/ otherwise.",
    {
      validator: program.STRING,
      default: "",
    },
  )
  .option(
    "--excalidraw-version [excalidraw-version]",
    "The version of Excalidraw to use. If not specified, it will be detected automatically.",
    {
      validator: [...VALID_EXCALIDRAW_VERSIONS, ""],
      default: "",
    },
  )
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
    "Time (in milliseconds) for each action to sleep. Defaults to 100. Too short and dialogs won't open in time. Too long and it will take longer to run.",
    {
      validator: program.INTEGER,
      default: 200,
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
