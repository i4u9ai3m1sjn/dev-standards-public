// dev-standards: Allure 3 のレポート設定。`npx -y allure@3.22.1 generate` がこのファイルを自動で読む。
// プロジェクトごとに変えるのは name だけ。
export default {
  name: "__REPO_NAME__ テストレポート",
  output: "out/allure-report",
  plugins: {
    awesome: {
      options: {
        singleFile: true, // 動画・スクショを埋め込んだ HTML 1ファイル（ダブルクリックで開ける）
        reportLanguage: "ja",
        groupBy: ["parentSuite", "suite", "subSuite"],
      },
    },
  },
};
