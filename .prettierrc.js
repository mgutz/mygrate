module.exports = {
  // use `{a, b}` instead of `{ a, b }` which is inconsistent
  // with other brackets, eg `const [state, setState] = useState(0)`
  bracketSpacing: false,

  endOfLine: "lf",
  printWidth: 80,
  trailingComma: "es5",
  tabWidth: 2,
  useTabs: false,
  semi: false,
  singleQuote: true,
  jsxBracketSameLine: false,
  // favor x => y instead of (x) => y
  arrowParens: "avoid",
};
