import React, { useState } from 'react';
import metricsData from '@site/static/data/pagespeed-metrics.json';

export default function PageSpeedMetrics() {
  const [viewMode, setViewMode] = useState('mobile'); // 'mobile' or 'desktop'

  // Data is now loaded at build time
  const data = metricsData;
  const loading = false;
  const error = null;

  if (loading) {
    return (
      <div className="pagespeed-container">
        <div className="loading">Loading metrics...</div>
        <style>{styles}</style>
      </div>
    );
  }

  if (error || !data || !data.metrics || data.metrics.length === 0) {
    return (
      <div className="pagespeed-container">
        <div className="error">No metrics available yet. Push a commit to main to collect data!</div>
        <style>{styles}</style>
      </div>
    );
  }

  const metrics = data.metrics.slice(0, 4).reverse(); // Last 4 measurements, chronologically

  // Format date for display
  const formatDate = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  };

  const formatFullDate = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  // Small multiples chart component - minimalist approach
  const SmallMultiplesChart = ({ data, viewMode }) => {
    const [tooltip, setTooltip] = React.useState({ visible: false, x: 0, y: 0, content: null });
    const isMobile = viewMode === 'mobile';

    const categories = [
      { key: 'performance_score', label: 'Performance' },
      { key: 'accessibility_score', label: 'Accessibility' },
      { key: 'best_practices_score', label: 'Best Practices' },
      { key: 'seo_score', label: 'SEO' }
    ];

    // Use viewBox for scalable coordinates (100 units wide, flexible height)
    const viewBoxWidth = 100;
    const viewBoxHeight = 28;
    const padding = {
      top: 11,
      right: 15,
      bottom: 3,
      left: 3
    };
    const innerWidth = viewBoxWidth - padding.left - padding.right;
    const innerHeight = viewBoxHeight - padding.top - padding.bottom;

    // Shared scale: 60-100 for all charts
    const minValue = 60;
    const maxValue = 100;

    const getXPosition = (index, total) => {
      if (total === 1) return padding.left + innerWidth / 2;
      return padding.left + (index / (total - 1)) * innerWidth;
    };

    const getYPosition = (value) => {
      return padding.top + innerHeight - ((value - minValue) / (maxValue - minValue)) * innerHeight;
    };

    // Only show minimal grid lines (75 and 90)
    const gridValues = [75, 90];

    const SingleChart = ({ category, isLast, index }) => {
      const values = data.map(m => {
        const metric = isMobile ? m.mobile : m.desktop;
        return metric?.[category.key] || 0;
      });

      const points = values.map((value, i) => {
        const x = getXPosition(i, values.length);
        const y = getYPosition(value);

        return {
          x,
          y,
          value,
          timestamp: data[i].timestamp,
          commit: data[i].commit
        };
      });

      const currentValue = values[values.length - 1];

      const handleMouseEnter = (point, event) => {
        const svgRect = event.currentTarget.closest('svg').getBoundingClientRect();
        const containerRect = event.currentTarget.closest('.small-multiples-container').getBoundingClientRect();

        setTooltip({
          visible: true,
          x: svgRect.left - containerRect.left + (point.x / viewBoxWidth) * svgRect.width,
          y: svgRect.top - containerRect.top + (point.y / viewBoxHeight) * svgRect.height,
          content: {
            commit: point.commit,
            date: formatFullDate(point.timestamp)
          }
        });
      };

      const handleMouseLeave = () => {
        setTooltip({ visible: false, x: 0, y: 0, content: null });
      };

      return (
        <svg viewBox={`0 0 ${viewBoxWidth} ${viewBoxHeight}`} className="small-chart" preserveAspectRatio="xMidYMid meet">
          {/* Minimal grid lines */}
          {gridValues.map((val, i) => (
            <line
              key={i}
              x1={padding.left}
              y1={getYPosition(val)}
              x2={viewBoxWidth - padding.right}
              y2={getYPosition(val)}
              stroke="#f1f5f9"
              strokeWidth="0.15"
            />
          ))}

          {/* Line segments - green for improvements, red for declines */}
          {points.slice(0, -1).map((point, i) => {
            const nextPoint = points[i + 1];
            const isImprovement = nextPoint.value > point.value;
            const isDecline = nextPoint.value < point.value;
            const segmentColor = isImprovement ? '#10b981' : isDecline ? '#ef4444' : '#94a3b8';

            return (
              <line
                key={i}
                x1={point.x}
                y1={point.y}
                x2={nextPoint.x}
                y2={nextPoint.y}
                stroke={segmentColor}
                strokeWidth="0.3"
                strokeLinecap="round"
              />
            );
          })}

          {/* Points with score labels above */}
          {points.map((point, i) => (
            <g
              key={i}
              onMouseEnter={(e) => handleMouseEnter(point, e)}
              onMouseLeave={handleMouseLeave}
              style={{ cursor: 'pointer' }}
            >
              {/* Larger invisible circle for easier hovering */}
              <circle
                cx={point.x}
                cy={point.y}
                r="2"
                fill="transparent"
              />
              {/* Data point */}
              <circle
                cx={point.x}
                cy={point.y}
                r="1"
                fill="#1e293b"
              />
              {/* Score label above point */}
              <text
                x={point.x}
                y={point.y - 2.5}
                textAnchor="middle"
                fill="#1e293b"
                fontSize="3"
                fontWeight="600"
              >
                {Math.round(point.value)}
              </text>
            </g>
          ))}

          {/* Category label - top left */}
          <text
            x={padding.left}
            y={5}
            fill="#475569"
            fontSize="3.5"
            fontWeight="600"
          >
            {category.label}
          </text>
        </svg>
      );
    };

    return (
      <div className="small-multiples-container">
        <div className="chart-grid">
          {categories.map((cat, idx) => (
            <div key={idx} className="small-chart-wrapper">
              <SingleChart
                category={cat}
                isLast={idx === 2 || idx === 3}
                index={idx}
              />
            </div>
          ))}
        </div>

        {/* Minimal tooltip */}
        {tooltip.visible && tooltip.content && (
          <div
            className="chart-tooltip-minimal"
            style={{
              left: `${tooltip.x}px`,
              top: `${tooltip.y}px`,
            }}
          >
            <a
              href={tooltip.content.commit.url}
              target="_blank"
              rel="noopener noreferrer"
              className="tooltip-commit-link"
            >
              {tooltip.content.commit.sha?.substring(0, 7)}
            </a>
            <div className="tooltip-date">{tooltip.content.date}</div>
          </div>
        )}
      </div>
    );
  };

  // Get latest commit for the header link
  const latestCommit = metrics[metrics.length - 1]?.commit;

  return (
    <div className="pagespeed-container">

      {/* Toggle */}
      <div className="view-toggle">
        <button
          className={`toggle-btn ${viewMode === 'mobile' ? 'active' : ''}`}
          onClick={() => setViewMode('mobile')}
        >
          Mobile
        </button>
        <button
          className={`toggle-btn ${viewMode === 'desktop' ? 'active' : ''}`}
          onClick={() => setViewMode('desktop')}
        >
          Desktop
        </button>
      </div>

      {/* Chart */}
      <SmallMultiplesChart data={metrics} viewMode={viewMode} />

      <style>{styles}</style>
    </div>
  );
}

const styles = `
  .pagespeed-container {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
    max-width: 1600px;
    margin: 2rem auto;
    padding: 0 1rem;
    min-height: 500px; /* Reserve space to prevent CLS */
  }

  .loading, .error {
    padding: 2rem;
    text-align: center;
    border-radius: 8px;
    margin: 2rem 0;
    min-height: 460px; /* Match container height to prevent CLS */
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .loading {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    color: #475569;
  }

  .error {
    background: #fef2f2;
    border: 1px solid #fecaca;
    color: #991b1b;
  }

  /* Header */
  .chart-header {
    text-align: center;
    margin-bottom: 2rem;
  }

  .chart-title {
    margin: 0 0 0.5rem 0;
    font-size: 1.5rem;
    font-weight: 600;
    color: #1e293b;
    letter-spacing: -0.025em;
  }

  .chart-subtitle {
    margin: 0;
    font-size: 0.875rem;
    color: #64748b;
    font-weight: 400;
  }

  .commit-link {
    color: #1e293b;
    text-decoration: none;
    font-family: 'SF Mono', 'Monaco', 'Courier New', monospace;
    font-size: 0.8125rem;
    padding: 2px 6px;
    background: #f1f5f9;
    border-radius: 3px;
    transition: all 0.15s;
  }

  .commit-link:hover {
    background: #e2e8f0;
    color: #3b82f6;
  }

  .view-toggle {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1.5rem;
    justify-content: center;
  }

  .toggle-btn {
    padding: 0.5rem 1rem;
    border: 1px solid #e2e8f0;
    background: white;
    border-radius: 6px;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s;
    color: #64748b;
  }

  .toggle-btn:hover {
    border-color: #cbd5e1;
    color: #475569;
  }

  .toggle-btn.active {
    border-color: #1e293b;
    background: #1e293b;
    color: white;
    font-weight: 600;
  }

  /* Small multiples container */
  .small-multiples-container {
    background: white;
    padding: 2rem 0;
    position: relative;
  }

  .chart-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 2rem 3rem;
    max-width: 1600px;
    margin: 0 auto;
  }

  .small-chart-wrapper {
    min-width: 0;
  }

  .small-chart {
    display: block;
    width: 100%;
    height: auto;
  }

  /* Score link styling */
  .score-link {
    cursor: pointer;
    transition: fill 0.15s;
  }

  .score-link:hover {
    fill: #3b82f6;
  }

  /* Minimal tooltip */
  .chart-tooltip-minimal {
    position: absolute;
    background: white;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    padding: 8px 10px;
    pointer-events: auto;
    z-index: 1000;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    transform: translate(-50%, -120%);
    white-space: nowrap;
  }

  .tooltip-commit-link {
    display: block;
    color: #3b82f6;
    text-decoration: underline;
    font-family: 'SF Mono', 'Monaco', 'Courier New', monospace;
    font-size: 0.8125rem;
    font-weight: 600;
    margin-bottom: 2px;
  }

  .tooltip-commit-link:hover {
    color: #2563eb;
  }

  .tooltip-date {
    font-size: 0.6875rem;
    color: #64748b;
  }

  @media (max-width: 1024px) {
    .chart-grid {
      grid-template-columns: 1fr;
      gap: 2rem;
    }

    .small-multiples-container {
      padding: 1rem 0;
    }
  }

  @media (max-width: 768px) {
    .view-toggle {
      flex-direction: column;
    }

    .toggle-btn {
      width: 100%;
    }
  }
`;
