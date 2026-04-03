import { Link } from "react-router-dom";

export default function TeamLogoLink({ teamId, className = "", title, children, stopPropagation = false }) {
  if (!teamId) {
    return <span className={className} title={title}>{children}</span>;
  }
  return (
    <Link
      to={`/team/${teamId}`}
      className={className}
      title={title}
      onClick={(e) => {
        if (stopPropagation) e.stopPropagation();
      }}
    >
      {children}
    </Link>
  );
}
