import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";

export default function TeamTrends({ data, metrics = ["xg","xga"], height = 180 }) {
  return (
    <div className="rounded-xl border border-glass bg-surface-2 p-3 text-slate-100">
      <div className="text-sm font-semibold mb-2">Динамика (роллинги)</div>
      <div style={{width:"100%", height}}>
        <ResponsiveContainer>
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#27364f" />
            <XAxis dataKey="date" tick={{fontSize:11, fill:"#94a3b8"}} />
            <YAxis tick={{fontSize:11, fill:"#94a3b8"}} />
            <Tooltip contentStyle={{ background: "#0b1220", border: "1px solid #1f2a44", color: "#e2e8f0" }} />
            {metrics.includes("xg")  && <Line type="monotone" dataKey="xg"  dot={false} />}
            {metrics.includes("xga") && <Line type="monotone" dataKey="xga" dot={false} />}
            {metrics.includes("shots") && <Line type="monotone" dataKey="shots" dot={false} />}
            {metrics.includes("possession") && <Line type="monotone" dataKey="possession" dot={false} />}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
