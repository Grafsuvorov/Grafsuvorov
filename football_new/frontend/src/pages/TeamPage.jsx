import { Navigate, useLocation, useParams } from "react-router-dom";

export default function TeamPage() {
  const { id } = useParams();
  const location = useLocation();
  const suffix = location.search || "";
  return <Navigate to={`/team/${id}${suffix}`} replace />;
}
