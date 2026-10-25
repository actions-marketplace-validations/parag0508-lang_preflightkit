// INTENTIONALLY INSECURE test fixture — do not copy.
export function Comment({ html }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}
