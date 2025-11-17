import React, { useEffect } from 'react';
import Mermaid from '@theme/Mermaid';

export default function PageSpeedMermaid({ chart }) {
  useEffect(() => {
    // Wait for Mermaid to render, then inject icons
    const timer = setTimeout(() => {
      const icons = {
        'eventbridge': 'https://icon.icepanel.io/AWS/svg/Application-Integration/EventBridge.svg',
        'lambda-collector': 'https://icon.icepanel.io/AWS/svg/Compute/Lambda.svg',
        'lambda-api': 'https://icon.icepanel.io/AWS/svg/Compute/Lambda.svg',
        'dynamodb': 'https://icon.icepanel.io/AWS/svg/Database/DynamoDB.svg',
        'apigateway': 'https://icon.icepanel.io/AWS/svg/Networking-Content-Delivery/API-Gateway.svg',
        'pagespeed': 'https://www.gstatic.com/pagespeed/insights/ui/logo/favicon_48.png',
        'github': 'https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png',
      };

      Object.entries(icons).forEach(([nodeId, iconUrl]) => {
        // Find the node's label element
        const node = document.querySelector(`#${nodeId}`);
        if (node) {
          // Find the rect element (the background box)
          const rect = node.querySelector('rect');
          const foreignObject = node.querySelector('foreignObject');

          if (rect && foreignObject) {
            // Get rect dimensions and position
            const x = parseFloat(rect.getAttribute('x'));
            const y = parseFloat(rect.getAttribute('y'));
            const width = parseFloat(rect.getAttribute('width'));

            // Create image element
            const img = document.createElementNS('http://www.w3.org/2000/svg', 'image');
            img.setAttributeNS('http://www.w3.org/1999/xlink', 'href', iconUrl);
            img.setAttribute('x', x + width / 2 - 20); // Center icon (40px / 2 = 20px)
            img.setAttribute('y', y + 12); // Top padding
            img.setAttribute('width', '40');
            img.setAttribute('height', '40');

            // Insert icon before the foreignObject (text)
            node.insertBefore(img, foreignObject);

            // Adjust foreignObject position to make room for icon
            const currentY = parseFloat(foreignObject.getAttribute('y'));
            foreignObject.setAttribute('y', currentY + 48); // Move text down (40px icon + 8px gap)
          }
        }
      });
    }, 100);

    return () => clearTimeout(timer);
  }, []);

  return <Mermaid value={chart} />;
}
