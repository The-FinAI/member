-- Add the NVIDIA B200 to the built-in GPU catalogue.
-- TFLOPs = FP16/BF16 dense tensor throughput (same basis as the rest of the
-- catalogue, e.g. H100 = 990). B200 ≈ 2.25 PFLOPS dense → 2250 TFLOPs.
-- Ranks above the H100 as the new top card.
insert into gpu_model (name, tflops, rank) values
  ('NVIDIA B200', 2250, 5)
on conflict (name) do nothing;
