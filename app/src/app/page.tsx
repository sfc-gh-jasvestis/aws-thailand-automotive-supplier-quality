'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface QualityData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; lots: number | null; flags: number | null }[];
  categories: { category: string; flags: number | null; confirmed: number | null }[];
  entities: Record<string, string | number | null>[];
  reviewRisk: { name: string; compliance: number; confirmed: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; flags: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<QualityData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['First-Pass Acceptance (parts)', 'Inspection Lots Received', 'Parts Inspected (millions)', 'Flag Precision'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">First-pass acceptance = parts accepted at incoming inspection / parts inspected. Flag precision = confirmed non-conformances / quality exception flags. Volumes are thousands of parts (bolts, panels, harness sets, mouldings, brake parts). Exception checks are demo signals, not supplier audit, PPAP or certification verdicts.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'lots', name: 'Inspection lots' }, { key: 'flags', name: 'Exception flags' }]} title="Daily Inspection Lots and Quality Exception Flags" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'flags', name: 'Flags' }, { key: 'confirmed', name: 'Confirmed non-conformances' }]} title="Exception Flags and Confirmed Non-Conformances by Exception Signal" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Supplier' }, { key: 'region', header: 'City' }, { key: 'category', header: 'Part category' },
        { key: 'lots', header: 'Lots' }, { key: 'accepted', header: 'Accepted (%)' }, { key: 'acceptedK', header: 'Accepted parts (M)' },
        { key: 'flags', header: 'Flags' }, { key: 'confirmed', header: 'Confirmed' }, { key: 'precision', header: 'Precision (%)' },
      ]} data={data?.entities ?? []} title="Supplier observations" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day non-conformance risk and inspection lot forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a supplier has a confirmed non-conformance in the next 7 days,
        from dimensional deviation, the share of parts rejected at incoming inspection, recent confirmed non-conformances, days since the last supplier quality review, the 30-day review completion rate, risk tier, years in the supplier development programme and part category.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} supplier-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Supplier' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(non-conformance in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Non-conformance risk by supplier" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Network-wide inspection lot forecast, next 14 days (lots per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Supplier' }, { key: 'date', header: 'Date' }, { key: 'variance', header: 'Deviation (% of tolerance)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Dimensional deviation anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live inspections: Firehose to Snowpipe' : 'Live inspections: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated incoming-inspection lot results are sent to Amazon Data Firehose (aws/publish_inspections.py), which writes them to the S3 landing bucket under inspections/, and Snowpipe auto-ingest loads them into RAW.LIVE_INSPECTIONS.'
          : 'CALL APP.SIMULATE_INSPECTIONS(n) inserts simulated incoming-inspection lot results directly into RAW.LIVE_INSPECTIONS (or resume APP.TASK_SIMULATE_INSPECTIONS for a feed every minute). This simulates an inspection result feed; it is not Snowpipe Streaming.'}
        {' '}A FLAG event is a lot whose dimensional deviation is above 75% of the tolerance band. The alert APP.LIVE_INSPECTION_ALERT logs FLAG events and emails the supplier quality team.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Inspection events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="FLAG events" value={String(data?.liveSummary?.flags ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Supplier' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'kparts', header: 'Parts (k)' },
        { key: 'variance', header: 'Deviation (% of tolerance)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 inspection lot events" />
      <DataTable columns={[
        { key: 'id', header: 'Supplier' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'kparts', header: 'Parts (k)' },
        { key: 'variance', header: 'Deviation (% of tolerance)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Inspection alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Quality Review Completion" value={kpiVal('Quality Review Completion')} />
        <KPICard title="PPAP Approval Coverage" value={kpiVal('PPAP Approval Coverage')} />
        <KPICard title="PPAP Submissions Pending" value={kpiVal('PPAP Submissions Pending')} />
      </div>
      <Chart data={data?.reviewRisk ?? []} type="scatter" xKey="compliance" xName="Review completion"
        yKeys={[{ key: 'confirmed', name: 'Confirmed non-conformances' }]} yDomain={[0, 'auto']}
        title="Quality review completion (%) vs confirmed non-conformances by supplier" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that reviews prevented non-conformances.</p>
      <ActionMemo persona={{ name: 'Siriporn Wongsakul', role: 'Head of Supplier Quality (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft supplier quality follow-up actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, supplier, exception-signal and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.SUPPLIER_QUALITY_AGENT. It uses Cortex Analyst over the semantic view APP.SUPPLIER_QUALITY_ANALYTICS for metrics, and Cortex Search over synthetic incoming-inspection containment SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the supplier quality agent" mode="advisor" sampleQuestions={['Which 3 suppliers have the most confirmed non-conformances?', 'Which suppliers are high risk this week and what SOP applies?', 'What is first-pass acceptance by part category?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: synthetic automotive parts suppliers (8 Thai cities x 5 part categories), daily incoming-inspection observations and a PPAP status snapshot. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION non-conformance risk model evaluated on a time-based holdout, plus a 14-day inspection lot FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags dimensional deviation outliers per supplier over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: inspection lot events sent to Amazon Data Firehose, delivered to S3, then Snowpipe auto-ingest (SQS) into RAW.LIVE_INSPECTIONS, with a Snowflake alert and email on FLAG events.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily inspection lots, confirmed non-conformances by supplier, non-conformance risk), with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_INSPECTIONS inserts simulated inspection lot events into RAW.LIVE_INSPECTIONS, with a Snowflake alert and email on FLAG events. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Reviews & PPAP', icon: '', content: planning },
    { id: 'live', label: 'Live Inspections', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for fictional automotive parts suppliers. On-demand snapshots are not live operations, and exception checks are not supplier audit, PPAP or certification verdicts.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No supplier observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Thailand Automotive Supplier Quality" tabs={tabs} />;
}
