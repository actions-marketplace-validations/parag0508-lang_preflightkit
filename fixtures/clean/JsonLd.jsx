// Structured data: serialized JSON, with "<" escaped so it can't close the tag.
export function JsonLd({ data }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{
        // nosemgrep: typescript.react.security.audit.react-dangerouslysetinnerhtml.react-dangerouslysetinnerhtml -- serialized JSON, "<" escaped
        __html: JSON.stringify(data).replace(/</g, '\\u003c'),
      }}
    />
  );
}
