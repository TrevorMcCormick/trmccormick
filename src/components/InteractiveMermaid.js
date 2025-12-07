import React, { useEffect, useState, useRef } from 'react';
import Mermaid from '@theme/Mermaid';

export default function InteractiveMermaid({ chart, descriptions }) {
  const [selectedNode, setSelectedNode] = useState(null);
  const [nodeColors, setNodeColors] = useState({});
  const containerRef = useRef(null);

  useEffect(() => {
    const attachHandlers = () => {
      if (!containerRef.current) {
        console.log('InteractiveMermaid: No containerRef');
        return false;
      }

      const svg = containerRef.current.querySelector('svg');
      if (!svg) {
        console.log('InteractiveMermaid: No SVG found');
        return false;
      }

      console.log('InteractiveMermaid: SVG found, attempting to attach handlers');

      // Debug: Log all elements with IDs in the SVG
      const allElementsWithIds = containerRef.current.querySelectorAll('[id]');
      console.log('InteractiveMermaid: All elements with IDs:', Array.from(allElementsWithIds).map(el => el.id));

      // Find all clickable nodes in the Mermaid SVG
      const nodeIds = Object.keys(descriptions);
      console.log('InteractiveMermaid: Looking for node IDs:', nodeIds);
      let attached = 0;

      nodeIds.forEach(nodeId => {
        // Mermaid generates IDs like "flowchart-eventbridge-0", "flowchart-lambda-collector-1", etc.
        // We need to find the <g> element that contains the node, not the edges
        const node = containerRef.current.querySelector(`g[id^="flowchart-${nodeId}-"]`);

        if (node) {
          console.log(`InteractiveMermaid: Found node for ${nodeId}`, node);

          // Extract colors from the node's rect element
          const rect = node.querySelector('rect, path, polygon');
          if (rect) {
            const computedStyle = window.getComputedStyle(rect);
            const fill = computedStyle.fill || computedStyle.backgroundColor;
            const stroke = computedStyle.stroke || computedStyle.borderColor;

            // Store the colors for this node
            setNodeColors(prev => ({
              ...prev,
              [nodeId]: {
                background: fill,
                border: stroke
              }
            }));
          }

          // Make it look clickable
          node.style.cursor = 'pointer';

          // Add click handler
          const clickHandler = (e) => {
            e.stopPropagation();
            console.log(`InteractiveMermaid: Clicked ${nodeId}`);
            setSelectedNode(nodeId);
          };
          node.addEventListener('click', clickHandler);

          // Add hover effect
          node.addEventListener('mouseenter', () => {
            const rect = node.querySelector('rect, path, polygon');
            if (rect) {
              rect.style.filter = 'brightness(0.95)';
            }
          });

          node.addEventListener('mouseleave', () => {
            const rect = node.querySelector('rect, path, polygon');
            if (rect) {
              rect.style.filter = 'brightness(1)';
            }
          });

          attached++;
        } else {
          console.log(`InteractiveMermaid: Could not find node for ${nodeId}`);
        }
      });

      console.log(`InteractiveMermaid: Attached ${attached} handlers`);
      return attached > 0;
    };

    // Try multiple times with increasing delays
    const attempts = [100, 300, 500, 1000];
    const timers = [];

    attempts.forEach(delay => {
      const timer = setTimeout(() => {
        const success = attachHandlers();
        if (success) {
          // Clear remaining timers if successful
          timers.forEach(t => clearTimeout(t));
        }
      }, delay);
      timers.push(timer);
    });

    return () => {
      timers.forEach(timer => clearTimeout(timer));
    };
  }, [descriptions, chart]);

  const selectedDescription = selectedNode ? descriptions[selectedNode] : null;
  const selectedColors = selectedNode ? nodeColors[selectedNode] : null;

  const closeModal = () => setSelectedNode(null);

  return (
    <div className="interactive-mermaid-container">
      <div ref={containerRef} className="mermaid-diagram">
        <Mermaid value={chart} />
      </div>

      {selectedDescription && (
        <>
          <div className="modal-overlay" onClick={closeModal} />
          <div className="modal-content" style={{
            backgroundColor: selectedColors?.background || '#f8fafc',
            borderColor: selectedColors?.border || '#0ea5e9'
          }}>
            <button className="modal-close" onClick={closeModal}>&times;</button>
            <h3 style={{ color: selectedColors?.border || '#0ea5e9' }}>
              {selectedDescription.title}
            </h3>
            <p
              style={{ whiteSpace: 'pre-line' }}
              dangerouslySetInnerHTML={{ __html: selectedDescription.description }}
            />
          </div>
        </>
      )}

      <style>{`
        .interactive-mermaid-container {
          margin: 2rem 0;
        }

        .mermaid-diagram {
          width: 100%;
          overflow-x: auto;
          margin-bottom: 2rem;
          display: flex;
          justify-content: center;
          min-height: 400px; /* Reserve space to prevent CLS */
        }

        .mermaid-diagram svg {
          width: 550px !important;
          max-width: 100% !important;
          height: auto !important;
        }

        .modal-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background-color: rgba(0, 0, 0, 0.5);
          z-index: 1000;
          animation: fadeIn 0.2s ease-out;
        }

        .modal-content {
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          max-width: 600px;
          width: 90%;
          padding: 2rem;
          border: 3px solid;
          border-radius: 12px;
          box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
          z-index: 1001;
          animation: slideUp 0.3s ease-out;
        }

        .modal-close {
          position: absolute;
          top: 1rem;
          right: 1rem;
          background: none;
          border: none;
          font-size: 2rem;
          line-height: 1;
          cursor: pointer;
          color: #64748b;
          padding: 0;
          width: 32px;
          height: 32px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 4px;
          transition: background-color 0.2s;
        }

        .modal-close:hover {
          background-color: rgba(0, 0, 0, 0.05);
        }

        .modal-content h3 {
          margin-top: 0;
          margin-bottom: 1rem;
          font-size: 1.5rem;
          font-weight: 600;
          padding-right: 2rem;
        }

        .modal-content p {
          margin: 0;
          color: #475569;
          line-height: 1.7;
          font-size: 1.0625rem;
        }

        @keyframes fadeIn {
          from { opacity: 0; }
          to { opacity: 1; }
        }

        @keyframes slideUp {
          from {
            opacity: 0;
            transform: translate(-50%, -45%);
          }
          to {
            opacity: 1;
            transform: translate(-50%, -50%);
          }
        }
      `}</style>
    </div>
  );
}
