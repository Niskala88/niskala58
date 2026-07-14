export default function Logo({ size = "small" }) {
  const height = size === "large" ? 100 : 36;
  return (
    <img
      src="/logo.png"
      alt="Niskala"
      style={{ height, width: "auto", display: "block" }}
    />
  );
}
