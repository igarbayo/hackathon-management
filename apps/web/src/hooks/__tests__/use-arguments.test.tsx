import type { ReactNode } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act, renderHook, waitFor } from "@testing-library/react";
import { useVoteArgument } from "@/hooks/use-arguments";
import { apiClient } from "@/lib/api-client";
import type { Feature } from "@/types/api";

const featureKey = ["teams", "t1", "features", "F-1"];

function setup(feature: Partial<Feature>) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  queryClient.setQueryData(featureKey, feature);
  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
  const { result } = renderHook(() => useVoteArgument("t1", "F-1"), { wrapper });
  return { queryClient, result };
}

const argument = { id: "a1", kind: "pro" as const, text: "Good", author_id: "u1", votes: 0, voted_by_me: false, created_at: "" };

describe("useVoteArgument (RF-PC-011)", () => {
  afterEach(() => vi.restoreAllMocks());

  it("fills the vote right away, before the API answers", async () => {
    let resolve: (value: unknown) => void = () => {};
    vi.spyOn(apiClient, "put").mockReturnValue(new Promise((r) => (resolve = r)) as never);
    const { queryClient, result } = setup({ arguments: [argument] });

    act(() => result.current.mutate({ argumentId: "a1", voted: false }));

    await waitFor(() =>
      expect(queryClient.getQueryData<Feature>(featureKey)?.arguments?.[0]).toMatchObject({ voted_by_me: true, votes: 1 }),
    );
    resolve({});
  });

  it("goes back to the previous state if the vote fails", async () => {
    vi.spyOn(apiClient, "delete").mockRejectedValue(new Error("boom"));
    const { queryClient, result } = setup({ arguments: [{ ...argument, votes: 1, voted_by_me: true }] });

    act(() => result.current.mutate({ argumentId: "a1", voted: true }));

    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(queryClient.getQueryData<Feature>(featureKey)?.arguments?.[0]).toMatchObject({ voted_by_me: true, votes: 1 });
  });
});
