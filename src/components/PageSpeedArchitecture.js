import React from 'react';

export default function PageSpeedArchitecture() {
  const iconStyle = {
    width: '48px',
    height: '48px',
    marginBottom: '8px',
  };

  const createNode = (iconUrl, title, subtitle, subtitle2, bgColor, borderColor) => ({
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '20px 24px',
    border: `2px solid ${borderColor}`,
    borderRadius: '12px',
    backgroundColor: bgColor,
    minWidth: '160px',
    textAlign: 'center',
    boxShadow: '0 2px 8px rgba(0,0,0,0.08)',
    transition: 'transform 0.2s, box-shadow 0.2s',
  });

  const containerStyle = {
    padding: '48px 20px',
    background: 'linear-gradient(135deg, #fafbfc 0%, #f3f4f6 100%)',
    borderRadius: '16px',
    margin: '2.5rem 0',
  };

  const arrowStyle = {
    fontSize: '20px',
    color: '#94a3b8',
    margin: '0 16px',
    fontWeight: '600',
  };

  const rowStyle = {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: '32px',
    flexWrap: 'wrap',
    gap: '24px',
  };

  return (
    <div style={containerStyle}>
      {/* Row 1: EventBridge */}
      <div style={rowStyle}>
        <div style={createNode(null, null, null, null, '#fff4e6', '#ffb366')}>
          <img src="https://icon.icepanel.io/AWS/svg/Application-Integration/EventBridge.svg" alt="EventBridge" style={iconStyle} />
          <div style={{fontSize: '15px', fontWeight: '600', color: '#1e293b'}}>EventBridge</div>
          <div style={{fontSize: '13px', color: '#64748b', marginTop: '4px'}}>Cron Rule</div>
          <div style={{fontSize: '12px', color: '#94a3b8'}}>Every Monday</div>
        </div>
      </div>

      <div style={{textAlign: 'center', margin: '12px 0', fontSize: '28px', color: '#94a3b8'}}>↓</div>

      {/* Row 2: Lambda Collector + External APIs */}
      <div style={rowStyle}>
        <div style={createNode(null, null, null, null, '#fff4e6', '#ffb366')}>
          <img src="https://icon.icepanel.io/AWS/svg/Compute/Lambda.svg" alt="Lambda" style={iconStyle} />
          <div style={{fontSize: '15px', fontWeight: '600', color: '#1e293b'}}>Lambda</div>
          <div style={{fontSize: '13px', color: '#64748b'}}>Collector</div>
        </div>

        <div style={{display: 'flex', flexDirection: 'column', gap: '24px'}}>
          <div style={{display: 'flex', alignItems: 'center'}}>
            <span style={arrowStyle}>→</span>
            <div style={createNode(null, null, null, null, '#eff6ff', '#60a5fa')}>
              <img src="https://www.gstatic.com/pagespeed/insights/ui/logo/favicon_48.png" alt="PageSpeed Insights" style={iconStyle} />
              <div style={{fontSize: '15px', fontWeight: '600', color: '#1e293b'}}>PageSpeed</div>
              <div style={{fontSize: '13px', color: '#64748b'}}>Insights API</div>
            </div>
            <span style={arrowStyle}>→</span>
          </div>

          <div style={{display: 'flex', alignItems: 'center'}}>
            <span style={arrowStyle}>→</span>
            <div style={createNode(null, null, null, null, '#f8fafc', '#cbd5e1')}>
              <img src="https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png" alt="GitHub" style={iconStyle} />
              <div style={{fontSize: '15px', fontWeight: '600', color: '#1e293b'}}>GitHub API</div>
              <div style={{fontSize: '13px', color: '#64748b'}}>Latest commit</div>
            </div>
            <span style={arrowStyle}>→</span>
          </div>
        </div>
      </div>

      <div style={{textAlign: 'center', margin: '12px 0', fontSize: '28px', color: '#94a3b8'}}>↓</div>

      {/* Row 3: DynamoDB */}
      <div style={rowStyle}>
        <div style={createNode(null, null, null, null, '#eef2ff', '#818cf8')}>
          <img src="https://icon.icepanel.io/AWS/svg/Database/DynamoDB.svg" alt="DynamoDB" style={iconStyle} />
          <div style={{fontSize: '15px', fontWeight: '600', color: '#1e293b'}}>DynamoDB</div>
          <div style={{fontSize: '12px', color: '#64748b', marginTop: '6px', lineHeight: '1.5'}}>
            Scores • Core Vitals<br/>
            Opportunities • Commits
          </div>
        </div>
      </div>

      <div style={{textAlign: 'center', margin: '12px 0', fontSize: '28px', color: '#94a3b8'}}>↓</div>

      {/* Row 4: API Gateway + Lambda API */}
      <div style={rowStyle}>
        <div style={createNode(null, null, null, null, '#fdf2f8', '#f472b6')}>
          <img src="https://icon.icepanel.io/AWS/svg/Networking-Content-Delivery/API-Gateway.svg" alt="API Gateway" style={iconStyle} />
          <div style={{fontSize: '15px', fontWeight: '600', color: '#1e293b'}}>API Gateway</div>
        </div>

        <span style={arrowStyle}>→</span>

        <div style={createNode(null, null, null, null, '#fff4e6', '#ffb366')}>
          <img src="https://icon.icepanel.io/AWS/svg/Compute/Lambda.svg" alt="Lambda" style={iconStyle} />
          <div style={{fontSize: '15px', fontWeight: '600', color: '#1e293b'}}>Lambda</div>
          <div style={{fontSize: '13px', color: '#64748b'}}>API Handler</div>
        </div>
      </div>

      <div style={{textAlign: 'center', margin: '12px 0', fontSize: '28px', color: '#94a3b8'}}>↓</div>

      {/* Row 5: This Page */}
      <div style={rowStyle}>
        <div style={createNode(null, null, null, null, '#f0fdf4', '#86efac')}>
          <div style={{fontSize: '40px', marginBottom: '8px'}}>📊</div>
          <div style={{fontSize: '15px', fontWeight: '600', color: '#1e293b'}}>This Page</div>
          <div style={{fontSize: '13px', color: '#64748b'}}>Chart.js visualization</div>
        </div>
      </div>
    </div>
  );
}
