// dev-standards: 画面のある E2E 用の Playwright 設定。
// `@AC` の付いたテストは動画・スクショ・トレースを常に撮り、それ以外は失敗したときだけ残す。
// 置き場所は tests/l0〜l4（.claude/rules/testing.md §6）。動かすレベルはパスで選ぶ（例: playwright test tests/l2）。
// `@manual` の付いたテストは RUN_MANUAL=1 のときだけ動かす。
import { defineConfig } from '@playwright/test';

const manual = process.env.RUN_MANUAL === '1' ? [] : [/@manual/];

export default defineConfig({
  testDir: 'tests',
  testMatch: 'l{0,1,2,3,4}/**/*.spec.ts',
  outputDir: 'out/test-results',
  reporter: [
    ['list'],
    ['junit', { outputFile: 'out/junit-e2e.xml' }],
    ['allure-playwright', { resultsDir: 'out/allure-results' }],
  ],
  use: {
    // baseURL: 'http://localhost:3000',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'acceptance', grep: /@AC/, grepInvert: manual, use: { screenshot: 'on', video: 'on', trace: 'on' } },
    { name: 'e2e', grepInvert: [/@AC/, ...manual] },
  ],
  // webServer: { command: 'npm run start', url: 'http://localhost:3000', reuseExistingServer: !process.env.CI },
});
