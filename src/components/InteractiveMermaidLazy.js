import React from 'react';
import BrowserOnly from '@docusaurus/BrowserOnly';

export default function InteractiveMermaidLazy(props) {
  return (
    <BrowserOnly
      fallback={
        <div
          style={{
            minHeight: '500px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: '#f8fafc',
            borderRadius: '8px',
          }}
        >
          Loading diagram...
        </div>
      }
    >
      {() => {
        const InteractiveMermaid = require('./InteractiveMermaid').default;
        return <InteractiveMermaid {...props} />;
      }}
    </BrowserOnly>
  );
}
