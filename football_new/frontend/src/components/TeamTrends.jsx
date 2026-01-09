import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";

export default function TeamTrends({ data, metrics = ["xg","xga"], height = 180 }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-3">
      <div className="text-sm font-semibold mb-2">Динамика (роллинги)</div>
      <div style={{width:"100%", height}}>
        <ResponsiveContainer>
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3"/>
            <XAxis dataKey="date" tick={{fontSize:11}} />
            <YAxis tick={{fontSize:11}} />
            <Tooltip />
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
