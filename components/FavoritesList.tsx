"use client";
import { Project } from "@/data/projects";
import { useFavorites } from "@/hooks/useFavorites";
import ProjectTable from "@/components/ProjectTable";

export default function FavoritesList({ items }: { items: Project[] }) {
  const { favorites } = useFavorites();
  const filtered = items.filter((p) => favorites.includes(p.slug));

  if (!filtered.length) {
    return (
      <p className="muted" style={{ padding: "40px 0", textAlign: "center" }}>
        No favorites yet. Click the star on any drop to save it here.
      </p>
    );
  }

  return <ProjectTable items={filtered} />;
}