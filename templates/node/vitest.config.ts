// dev-standards: コンポーネント・統合テスト（Vitest）を Allure と JUnit XML に出す設定。
// 置き場所は tests/l0〜l4（.claude/rules/testing.md §6）。動かすレベルはパスで選ぶ（例: vitest run tests/l0 tests/l1 tests/l2）。
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/l{0,1,2,3,4}/**/*.test.ts'],
    setupFiles: ['allure-vitest/setup'],
    reporters: [
      'default',
      ['junit', { outputFile: 'out/junit-unit.xml' }],
      ['allure-vitest/reporter', { resultsDir: 'out/allure-results' }],
    ],
  },
});
