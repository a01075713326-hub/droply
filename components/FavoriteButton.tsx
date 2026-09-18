"use client";
import { useFavorites } from "@/hooks/useFavorites";

export default function FavoriteButton({ slug }: { slug: string }) {
  const { isFavorite, toggleFavorite } = useFavorites();
  const active = isFavorite(slug);

  return (
    <button
      type="button"
      className={"favorite-btn" + (active ? " favorite-btn-active" : "")}
      aria-label={active ? "Remove from favorites" : "Add to favorites"}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        toggleFavorite(slug);
      }}
    >
      {active ? "\u2605" : "\u2606"}
    </button>
  );
}