import Link from "next/link"

interface Post {
    id: string
    title: string
    slug: string
    // excerpt?: string
    // published_at: string
}

async function getPosts() {
    const backendUrl = process.env.NEXT_PUBLIC_MEDUSA_BACKEND_URL || "http://localhost:9000"
    try {
        const res = await fetch(`${backendUrl}/store/blog`, {
            next: { revalidate: 3600 } // Cache for 1 hour
        })

        if (!res.ok) {
            throw new Error(`Failed to fetch posts: ${res.statusText}`)
        }

        const data = await res.json()
        // console.log("Blog data:", data)
        return data.posts || []
    } catch (err) {
        console.error("Error fetching blog posts:", err)
        return []
    }
}

export default async function BlogIndex() {
    const posts = await getPosts()

    return (
        <div className="container mx-auto px-4 py-12 max-w-4xl">
            <h1 className="text-4xl font-bold mb-8">Blog</h1>

            {posts.length === 0 ? (
                <p className="text-gray-500">No posts found.</p>
            ) : (
                <div className="grid gap-8">
                    {posts.map((post: Post) => (
                        <div key={post.id} className="border p-6 rounded-lg shadow-sm hover:shadow-md transition-shadow">
                            <h2 className="text-2xl font-semibold mb-2">
                                <Link href={`/blog/${post.slug}`} className="hover:underline">
                                    {post.title}
                                </Link>
                            </h2>
                            {/* <p className="text-gray-600 mb-4">{post.excerpt}</p> */}
                            <Link href={`/blog/${post.slug}`} className="text-blue-600 hover:underline">
                                Read more &rarr;
                            </Link>
                        </div>
                    ))}
                </div>
            )}

            <div className="mt-12">
                <Link href="/" className="text-gray-500 hover:text-gray-900">&larr; Back to Shop</Link>
            </div>
        </div>
    )
}
