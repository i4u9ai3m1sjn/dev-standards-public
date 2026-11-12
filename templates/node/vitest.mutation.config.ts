// dev-standards: ミューテーションテスト（StrykerJS）で使う Vitest の設定。殺す側のテストは L0〜L2 だけ（.claude/rules/testing.md §10）。
// ミュータントの数だけテストを流すので、Allure・JUnit XML のレポーターは外す（結果は out/mutation/ に出る）。
import { defineConfig, mergeConfig } from 'vitest/config';
import base from './vitest.config';

export default mergeConfig(base, defineConfig({
  test: {
    include: ['tests/l{0,1,2}/**/*.test.ts'],
    reporters: ['default'],
  },
}));
