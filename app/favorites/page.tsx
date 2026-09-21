import type { Metadata } from "next";
import { getProjects } from "@/lib/projects";
import FavoritesList from "@/components/FavoritesList";

export default async function FavoritesPage() {
  const projects = await getProjects();
  return (
    <main className="page container">
      <h1>Your Favorites</h1>
      <FavoritesList items={projects} />
    </main>
  );
}

export const metadata: Metadata = {
  robots: { index: false, follow: true },
};
